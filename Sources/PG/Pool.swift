import Foundation
import Dispatch


/// A pool of connections to postgres servers.
///
/// A connection pool creates multiple clients to connect to a single server in parallel. While each client executes queries asynchronously (to avoid locking a thread while it waits on IO), postgres servers can only excecute a single query per connection at a time.
///
/// Typically a server will use a single `Pool` to manage all of it's communications with the server.
public class Pool {
	/// The maximum number of clients the pool will create at one time.
	public let maximumConnections: Int
	
	public let idleTimeout: TimeInterval
	
	private let idleTimer: DispatchSourceTimer
	
	/// The number of workers used since the last idle timer check.
	///
	/// This is used to know the maximum number of clients we actually use at any given time.
	private var numberOfWorkersUsed: Int = 0
	
	/// A serial queue used for thread safety when accessing client properties
	private let queue = DispatchQueue(label: "PG.Pool")
	
	/// The client configuration the pool was created with.
	///
	/// New clients will be created using this config.
	public let config: Client.Config
	
	
	/// Create a new pool.
	///
	/// You can start issuing queries on the pool immediately. As queries are queued, new clients will be created and connected and the queries excecuted when the clients become available.
	///
	/// - Parameters:
	///   - config: The config to use when creating new clients.
	///   - maximumConnections: The maximum number of clients to create at one time.
	///   - idleTimeout: The amount of time to wait before disconnecting and destroying clients that aren't being used.
	public init(_ config: Client.Config, maximumConnections: Int = 10, idleTimeout: TimeInterval = 60 * 5) {
		self.config = config
		self.maximumConnections = maximumConnections
		self.idleTimeout = idleTimeout
		
		self.idleTimer = DispatchSource.makeTimerSource(queue: self.queue)
		idleTimer.scheduleRepeating(deadline: .now(), interval: .seconds(Int(idleTimeout)))
		idleTimer.setEventHandler() { [weak self] in
			self?.cleanupIdleWorkers()
		}
		idleTimer.resume()
	}
	
	deinit {
		for worker in workers {
			worker.client.disconnect()
		}
	}
	
	
	// MARK: - Worker management
	
	private class Worker {
		let queue: DispatchQueue
		var isAvailable: Bool
		let client: Client
		
		let becameAvailable = EventEmitter<Void>()
		
		init(_ client: Client, queue: DispatchQueue) {
			self.queue = queue
			self.isAvailable = true
			self.client = client
		}
		
		var isReady: Bool {
			return isAvailable && client.isConnected && client.isAuthenticated
		}
		
		
		func perform(_ block: @escaping PerformBlock) {
			self.isAvailable = false
			let client = self.client
			
			DispatchQueue.global().async() {
				block(client) {
					self.queue.async {
						self.isAvailable = true
						
						self.becameAvailable.emit()
					}
				}
			}
		}
	}
	
	private var workers: [Worker] = []
	
	private func createClient() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		let client = Client(self.config)
		let worker = Worker(client, queue: self.queue)
		workers.append(worker)
		
		client.connect { [weak self] (error) in
			guard let `self` = self else { return }
			self.queue.async {
				if let error = error {
					print("failed to connect client: \(error)\nremoving from pool in 30 seconds")
					
					self.queue.asyncAfter(deadline: .now() + 30) {
						self.remove(worker)
					}
				} else {
					print("connection successful")
					self._perform()
					
					client.disconnected.observe(on: self.queue) { [weak self, weak worker] in
						guard let worker = worker else { return }
						print("client disconnected, removing from workers")
						self?.remove(worker)
					}
				}
			}
		}
		
		worker.becameAvailable.observe(on: self.queue) { [weak self] in
			self?._perform()
		}
	}
	
	private func remove(_ worker: Worker) {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		self.workers = self.workers.filter({ $0 !== worker })
		
		worker.client.disconnect()
	}
	
	private func cleanupIdleWorkers() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		let workers = self.workers.filter({ $0.isReady }).prefix(self.workers.count - numberOfWorkersUsed)
		if !workers.isEmpty {
			print("claning up \(workers.count) unused idle workers in pool")
		}
		
		for worker in workers {
			self.remove(worker)
		}
		
		numberOfWorkersUsed = 0
	}
	
	
	// MARK: - Perform
	
	public typealias PerformCompletion = () -> Void
	public typealias PerformBlock = (_ client: Client, _ completion: @escaping PerformCompletion) -> Void
	
	private var performQueue: [PerformBlock] = []
	
	private func _perform() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		while !performQueue.isEmpty {
			if let worker = workers.first(where: { $0.isReady }) {
				let block = performQueue.removeFirst()
				
				worker.perform(block)
				
				numberOfWorkersUsed = max(numberOfWorkersUsed, self.workers.lazy.filter({ !$0.isReady }).count)
			} else {
				if workers.count < maximumConnections {
					self.createClient()
				}
				
				break
			}
		}
	}
	
	/// Excecute multiple commands on a client from the pool.
	///
	/// If you want to perform multiple queries on a single connection all at once (for instance for a transaction) or if you need to access a client for something other than a query, you can use this method to do so. Blocks will be queued up until a client is available. If needed, and `maximumConnections` has not been reached yet, a new client will be created.
	///
	/// - Note: You *must* call the completion callback when you are done with the client to let the pool know when you are done with the connection.
	///
	/// - Parameter block: The block to excecute with a client.
	public func perform(_ block: @escaping PerformBlock) {
		self.queue.async {
			self.performQueue.append(block)
			
			self._perform()
		}
	}
	
	/// Execute a query in a client.
	///
	/// If the query needs to be prepared, it will be done so automatically. On success, a `QueryResult` is returned that contains the type of result (INSERT, SELECT, etc) and any rows returned.
	///
	/// Note that the query will be queued until a client is available for excecution. If all clients are busy, and `maximumConnections` has not been reached, a new client will be created.
	///
	/// Setting `resultsMode` to `.binary` can improve performance, particularly for the timestamp types, however the binary encodings are undocumented and should be used with caution. If a text encoded value can't be parsed, it will gracefully fallback to a String, but in binary mode it will fallback to a `DataSlice` that may not be meaningful.
	///
	/// - Parameters:
	///   - query: The query to be execute.
	///   - resultsMode: The encoding mode to use for the result types.
	///   - callback: Called once the query has been executed and all data returned, or when an error occurs. Note that this is equivalent to the `query.completed` event.
	public func exec(_ query: Query, resultsMode: Field.Mode = .text, callback: ((Result<QueryResult>) -> Void)?) {
		self.perform() { (client, completion) in
			client.exec(query, resultsMode: resultsMode) { result in
				callback?(result)
				
				completion()
			}
		}
	}
}
