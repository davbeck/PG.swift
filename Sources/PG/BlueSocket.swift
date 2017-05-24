import Socket
import Foundation
import Dispatch


/// A socket that is implimented with [BlueSocket](https://github.com/IBM-Swift/BlueSocket)
public class BlueSocket: ConnectionSocket {
	fileprivate let queue = DispatchQueue(label: "BlueSocket")
	fileprivate let readDispatchQueue = DispatchQueue(label: "BlueSocket.read")
	fileprivate let writeDispatchQueue = DispatchQueue(label: "BlueSocket.write")
	
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
	/// - Throws: BlueSocket errors.
	public init(host: String, port: Int32) throws {
		self.host = host
		self.port = port
		self.socket = try Socket.create()
		
		try self.socket.setBlocking(mode: true)
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
		} catch {
			// TODO: handle errors
		}
	}
	
	public func close() {
		socket.close()
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
				try! self.socket.write(from: current.data)
				current.completion?()
			}
		}
	}
	
	
	// MARK: - Reading
	
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
	
	private var inputBuffer = Data()
	
	fileprivate func performRead() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		let readQueue = self.readQueue
		self.readQueue = []
		
		readDispatchQueue.async {
			// if we have any extra data left over from our last read, use it
			var inputBuffer = self.inputBuffer
			var offset = inputBuffer.startIndex
			
			for current in readQueue {
				while inputBuffer.count < current.length {
					// continue reading until our buffer has enough data
					_ = try! self.socket.read(into: &inputBuffer)
				}
				
				let range = offset..<current.length
				current.completion?(Data(inputBuffer[range]))
				offset = range.endIndex
			}
			
			// save the left overs for the next read
			self.inputBuffer = Data(inputBuffer.suffix(from: offset))
		}
	}
}
