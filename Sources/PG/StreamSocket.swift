#if os(Linux)
	// Foundation.Stream is mostly unimplimetned on Linux
#else
	import Foundation
	import Dispatch
	
	
	/// A socket that is implimented with NSStream
	public class StreamSocket: NSObject, ConnectionSocket {
		fileprivate let queue = DispatchQueue(label: "StreamSocket")
		
		/// The input stream for the socket
		public let input: InputStream
		/// The output stream for the socket
		public let output: OutputStream
		
		
		/// Create a new socket to connect to the given host and port
		///
		/// This does not establish a connection to the server. You need to still call `connect`.
		///
		/// - Parameters:
		///   - host: The hostname to connect to. Can be either an IP address or a domain name.
		///   - port: The port to connect on.
		public init?(host: String, port: Int) {
			var input: InputStream?
			var output: OutputStream?
			Stream.getStreamsToHost(withName: host, port: port, inputStream: &input, outputStream: &output)
			
			if let input = input, let output = output {
				self.input = input
				self.output = output
			} else {
				return nil
			}
		}
		
		
		// MARK: - Events
		
		/// Emitted when the connection is established with the server
		public let connected = EventEmitter<Void>(name: "PG.StreamSocket.connected")
		fileprivate var hasEmittedConnected = false
		
		
		// MARK: - Connection
		
		/// If the connection has been established
		public var isConnected: Bool {
			return self.input.streamStatus.isConnected && self.output.streamStatus.isConnected
		}
		
		/// Start a connection to the server
		public func connect() {
			for stream in [input, output] {
				stream.delegate = self
				stream.schedule(in: .current, forMode: .defaultRunLoopMode)
				stream.open()
			}
		}
		
		public func close() {
			for stream in [input, output] {
				stream.close()
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
			
			while output.hasSpaceAvailable {
				guard let current = writeQueue.first else { return }
				writeQueue.removeFirst()
				
				output.write(current.data)
				current.completion?()
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
		/// If the socket doesn't have data to read, this request is queued up and excecuted once data arrives.
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
			
			while input.hasBytesAvailable {
				guard let current = readQueue.first else { return }
				readQueue.removeFirst()
				
				guard let data = input.read(current.length) else { return } // TODO: handle this more gracefully
				current.completion?(data)
			}
		}
	}
	
	
	extension StreamSocket: StreamDelegate {
		public func stream(_ stream: Stream, handle eventCode: Stream.Event) {
			queue.async {
				switch eventCode {
				case Stream.Event.openCompleted:
					//				print("openCompleted \(stream)")
					if self.isConnected && !self.hasEmittedConnected {
						self.hasEmittedConnected = true
						self.connected.emit()
					}
				case Stream.Event.hasBytesAvailable:
					//				print("hasBytesAvailable")
					self.performRead()
				case Stream.Event.hasSpaceAvailable:
					//				print("hasSpaceAvailable")
					self.performWrite()
				case Stream.Event.errorOccurred:
					print("errorOccurred: \(stream.streamError!) \(stream)")
				case Stream.Event.endEncountered:
					print("endEncountered \(stream)")
				default:
					print("invalid event \(stream)")
					break
				}
			}
		}
	}
	
	
	public enum StreamError: Swift.Error {
		case notEnoughBytes
	}
	
	extension Stream.Status {
		var isConnected: Bool {
			switch self {
			case .atEnd, .error, .open, .reading, .writing:
				return true
			case .notOpen, .closed, .opening:
				return false
			}
		}
	}
	
	extension OutputStream {
		@discardableResult
		func write(_ bytes: UnsafeBufferPointer<UInt8>) -> Int {
			guard let baseAddress = bytes.baseAddress else { return 0 }
			return self.write(baseAddress, maxLength: bytes.count)
		}
		
		@discardableResult
		func write(_ data: Data) -> Int {
			var written = 0
			data.enumerateBytes { (bytes, offset, stop) in
				written += self.write(bytes)
			}
			return written
		}
	}
	
	extension InputStream {
		func read(_ count: Int) -> Data? {
			var data = Data(count: count)
			guard count > 0 else { return data }
			
			let readLength = data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Int in
				self.read(bytes, maxLength: count)
			}
			
			if readLength != count {
				return nil
			}
			
			return data
		}
	}
#endif
