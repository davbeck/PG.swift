import Socket
import Foundation
import Dispatch


/// A socket that is implimented with [AsyncSocket](https://github.com/IBM-Swift/AsyncSocket)
public class AsyncSocket: ConnectionSocket {
	fileprivate let queue = DispatchQueue(label: "AsyncSocket")
	fileprivate let readDispatchQueue = DispatchQueue(label: "AsyncSocket.read")
	fileprivate let writeDispatchQueue = DispatchQueue(label: "AsyncSocket.write")
	
	// we have to keep a reference to this to keep getting called
	fileprivate var readerSource: DispatchSourceRead?
	
	/// The underlying socket connection
	public let socket: Socket
	
	/// The host to use when connecting
	public let host: String
	
	/// The port to use when connecting
	public let port: Int32
	
	
	/// Create a new socket to connect to the given host and port
	///
	/// This does not establish a connection to the server. You need to still call `connect`.
	///
	/// - Parameters:
	///   - host: The host to use when connecting.
	///   - port: The port to use when connecting.
	/// - Throws: AsyncSocket errors.
	public init(host: String, port: Int32) throws {
		self.host = host
		self.port = port
		self.socket = try Socket.create()
		
		try self.socket.setBlocking(mode: false)
	}
	
	
	// MARK: - Events
	
	/// Emitted when the connection is established with the server
	public let connected = EventEmitter<Void>(name: "PG.StreamSocket.connected")
	fileprivate var hasEmittedConnected = false
	
	
	// MARK: - Connection
	
	/// If the connection has been established
	public var isConnected: Bool {
		return socket.isConnected
	}
	
	/// Start a connection to the server
	public func connect() {
		do {
			try socket.connect(to: host, port: port)
			self.connected.emit()
			
			
			let readerSource = DispatchSource.makeReadSource(fileDescriptor: self.socket.socketfd, queue: self.queue)
			readerSource.setEventHandler() {
				self.readBuffer()
			}
			readerSource.setCancelHandler() {
				self.close()
			}
			readerSource.resume()
			self.readerSource = readerSource
		} catch {
			// TODO: handle errors
		}
	}
	
	public func close() {
		if self.socket.socketfd > -1 {
			self.socket.close()
		}
	}
	
	
	// MARK: - Writing
	
	struct WriteItem {
		let data: Data
		let completion: (() -> Void)?
	}
	
	private var writeQueue: [WriteItem] = []
	
	/// Queue some data to be written to the socket
	///
	/// - Parameters:
	///   - data: The data to be written.
	///   - completion: Callback called when the data has been written.
	public func write(data: Data, completion: (() -> Void)? = nil) {
		queue.async {
			let item = WriteItem(data: data, completion: completion)
			self.writeQueue.append(item)
			
			self.performWrite()
		}
	}
	
	fileprivate func performWrite() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		let writeQueue = self.writeQueue
		self.writeQueue = []
		
		writeDispatchQueue.async {
			for current in writeQueue {
				let bytesWritten = try! self.socket.write(from: current.data)
				guard bytesWritten == current.data.count else {
//					print("bytesWritten: \(bytesWritten) of \(current.data.count)")
					fatalError()
				}
				current.completion?()
			}
		}
	}
	
	
	// MARK: - Reading
	
	private var inputBuffer = Data()
	
	fileprivate func readBuffer() {
		_ = try! self.socket.read(into: &self.inputBuffer)
		
		if self.inputBuffer.count > 0  {
			self.performRead()
		}
	}
	
	struct ReadRequest {
		let length: Int
		let completion: ((Data) -> Void)?
	}
	
	private var readQueue: [ReadRequest] = []
	
	/// Queue a read request
	///
	/// The socket will be polled on a background thread until enough data has been recieved.
	///
	/// - Parameters:
	///   - length: The number of bytes to read.
	///   - completion: Called when the data has been read.
	public func read(length: Int, completion: ((Data) -> Void)?) {
		queue.async {
			let request = ReadRequest(length: length, completion: completion)
			self.readQueue.append(request)
			
			self.performRead()
		}
	}
	
	fileprivate func performRead() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		// if we have any extra data left over from our last read, use it
		var inputBuffer = self.inputBuffer
		var offset = inputBuffer.startIndex
		
		while readQueue.count > 0 {
			let current = readQueue[0]
			guard inputBuffer.count >= current.length else { break }
			readQueue.removeFirst()
			
			let range = offset..<current.length
			current.completion?(Data(inputBuffer[range]))
			offset = range.endIndex
		}
		
		// save the left overs for the next read
		self.inputBuffer = Data(inputBuffer.suffix(from: offset))
	}
}
