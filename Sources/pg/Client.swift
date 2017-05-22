import Foundation


public final class Client: NotificationObservable {
	public enum Error: Swift.Error {
		case invalidConnectionURL
		case connectionFailure
	}
	
	
	public struct Config {
		public static let defaultPort = 5432
		
		
		public var user: String
		public var password: String?
		public var database: String?
		public var port: Int
		public var host: String
		public var useSSL: Bool
		
		public init(host: String = "localhost", user: String, password: String? = nil, database: String?, port: Int = Config.defaultPort, useSSL: Bool = false) {
			self.host = host
			self.user = user
			self.password = password
			self.database = database?.isEmpty ?? true ? nil : database
			self.port = port
			self.useSSL = useSSL
		}
		
		public init(url: URL) throws {
			guard url.scheme == "postgres" || url.scheme?.isEmpty ?? true else { throw Error.invalidConnectionURL }
			// TODO: Default individual config properties to ENV variables
			
			guard
				let host = url.host, !host.isEmpty,
				let user = url.user, !user.isEmpty,
				!url.path.isEmpty
				else { throw Error.invalidConnectionURL }
			
			self.init(
				host: host,
				user: user,
				password: url.password,
				database: url.path,
				port: url.port ?? Config.defaultPort
			)
		}
	}
	
	
	private let queue = DispatchQueue(label: "PG.Client")
	
	public let config: Config
	
	public var typeParser = TypeParser.default
	
	public var notificationObservers: [Observer] = []
	public private(set) var connection: Connection?
	
	public init(_ config: Config) {
		self.config = config
	}
	
	
	// MARK: - Notifications
	
	public let connected = EventEmitter<Void>(name: "PG.Client.connected")
	public let loginSuccess = EventEmitter<Void>(name: "PG.Client.loginSuccess")
	
	
	// MARK: -
	
	public var isConnected: Bool {
		return connection?.isConnected ?? false
	}
	
	public var isAuthenticated: Bool {
		return connection?.isAuthenticated ?? false
	}
	
	
	// MARK: -
	
	public func connect(completion: ((Error?) -> Void)?) {
		var completion = completion // we only want to call this once, so remove it when we do
		var input: InputStream?
		var output: OutputStream?
		
		Stream.getStreamsToHost(withName: config.host, port: config.port, inputStream: &input, outputStream: &output)
		
		if let input = input, let output = output {
			if config.useSSL {
				input.setProperty(kCFStreamSocketSecurityLevelTLSv1, forKey: .socketSecurityLevelKey)
				output.setProperty(kCFStreamSocketSecurityLevelTLSv1, forKey: .socketSecurityLevelKey)
			}
			
			let connection = Connection(input: input, output: output)
			self.connection = connection
			
			connection.loginSuccess.observe(on: self.queue) {
				completion?(nil)
				completion = nil
				
				self.loginSuccess.emit()
			}
			
			connection.connected.observe {
				self.connected.emit()
			}
			
			connection.readyForQuery.observe(on: self.queue) { _ in
				self.executeQuery()
			}
			
			for stream in [input, output] {
				stream.schedule(in: .current, forMode: .defaultRunLoopMode)
				stream.open()
			}
			
			connection.sendStartup(user: config.user, database: config.database)
		} else {
			completion?(Error.connectionFailure)
			completion = nil
		}
	}
	
	
	// MARK: - Query
	
	private var queryQueue: [Query] = []
	
	public func exec(_ query: Query, callback: ((Result) -> Void)?) {
		if let callback = callback {
			query.completed.once(callback)
		}
		
		queue.async {
			self.queryQueue.append(query)

			self.executeQuery()
		}
	}
	
	private func executeQuery() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		
		guard let connection = self.connection, connection.transactionStatus == .idle else { return }
		guard let query = queryQueue.first else { return }
		queryQueue.removeFirst()
		
		var fields: [Field] = []
		connection.rowDescriptionReceived.once() { fields = $0 }
		
		var rows: [[DataSlice?]] = []
		let rowReceived = connection.rowReceived.observe() { rowFields in
			rows.append(rowFields)
		}
		
		connection.commandComplete.once() { commandResponse in
			do {
				let result = try Result(commandResponse: commandResponse, fields: fields, rows: rows, typeParser: self.typeParser)
				query.completed.emit(result)
			} catch {
				// report error
			}
			
			rowReceived.remove()
		}
		
		connection.simpleQuery(query.string)
	}
}
