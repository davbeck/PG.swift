import Foundation


protocol NetworkOrderable {
	init()
	init(bigEndian value: Self)
	var bigEndian: Self { get }
}
extension Int8: NetworkOrderable {
	init(bigEndian value: Int8) {
		self.init(value)
	}
	
	var bigEndian: Int8 {
		return self
	}
}
extension UInt8: NetworkOrderable {
	init(bigEndian value: UInt8) {
		self.init(value)
	}
	
	var bigEndian: UInt8 {
		return self
	}
}
extension Int16: NetworkOrderable {}
extension UInt16: NetworkOrderable {}
extension Int32: NetworkOrderable {}
extension UInt32: NetworkOrderable {}


extension String {
	func data() -> Data {
		// utf8 is the one true encoding, and should never return have encoding issues, but if it does, allowLossyConversion will fail gracefully
		return self.data(using: .utf8, allowLossyConversion: true)!
	}
}

extension Data {
	func hexEncoded() -> String {
		return map { String(format: "%02hhx", $0) }.joined()
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
	func write<T: NetworkOrderable>(_ value: T) -> Int {
		var value = value.bigEndian
		return withUnsafePointer(to: &value) { buffer in
			buffer.withMemoryRebound(to: UInt8.self, capacity: 1, { buffer in
				self.write(buffer, maxLength: MemoryLayout<T>.size)
			})
		}
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
	func read<T: NetworkOrderable>() throws -> T {
		var value: T = T()
		let readLength = withUnsafeMutablePointer(to: &value) { (valuePointer) in
			valuePointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size, { (buffer) in
				self.read(buffer, maxLength: MemoryLayout<T>.size)
			})
		}
		
		guard readLength == MemoryLayout<T>.size else { throw StreamError.notEnoughBytes }
		
		return T(bigEndian: value)
	}
	
	func read(_ count: Int) -> Data {
		var data = Data()
		guard count > 0 else { return data }
		
		let bufferSize = 1024
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
		while data.count < count {
			let dataToRead = min(count - data.count, bufferSize)
			let readLength = self.read(buffer, maxLength: dataToRead)
			data.append(buffer, count: readLength)
			guard readLength == dataToRead else { break }
		}
		buffer.deinitialize()
		
		return data
	}
}


/// A simple wrapper around Data that writes information in Postgres specific formats.
struct Buffer {
	var data = Data()
	
	mutating func write<T: NetworkOrderable>(_ value: T) {
		var value = value.bigEndian
		data.append(UnsafeBufferPointer(start: &value, count: 1))
	}
	
	mutating func write(_ value: Int8) {
		var value = value
		data.append(UnsafeBufferPointer(start: &value, count: 1))
	}
	
	mutating func write(_ value: String) {
		data.append(value.data())
		self.write(0 as Int8)
	}
}



final class Connection: NSObject, StreamDelegate {
	enum Error: Swift.Error {
		case invalidStatusData
		case unrecognizedMessage
	}
	
	enum RequestType: UInt8 {
		case authentication = 82 // R
		case statusReport = 83 // S
		case backendKeyData = 75 // K
	}
	
	enum AuthenticationResponse: UInt32 {
		case authenticationOK = 0
		// case kerberosV5 = 2
		// case cleartextPassword = 3
		// case MD5Password = 5
		// case SCMCredential = 6
	}
	
	
	// MARK: - Notifications
	
	static let connected = NotificationDescriptor<VoidPayload>("PG.Connection.connected")
	static let loginSuccess = NotificationDescriptor<VoidPayload>("PG.Connection.loginSuccess")
	
	
	// MARK: - Initialization
	
	private let queue = DispatchQueue(label: "PG.Connection", qos: .userInteractive)
	let input: InputStream
	let output: OutputStream
	
	init(input: InputStream, output: OutputStream) {
		self.input = input
		self.output = output
		
		super.init()
		
		input.delegate = self
		output.delegate = self
	}
	
	
	// MARK: - 
	
	public var isConnected: Bool {
		return self.input.streamStatus.isConnected && self.output.streamStatus.isConnected
	}
	
	public private(set) var isAuthenticated: Bool = false
	
	public private(set) var parameters: [String:String] = [:]
	
	public private(set) var processID: Int32?
	
	public private(set) var secretKey: Int32?
	
	
	// MARK: - Writing
	
	struct WriteItem {
		let buffer: Buffer
		let completion: (() -> Void)?
		
		var offset: Int = 0
		
		init(buffer: Buffer, completion: (() -> Void)?) {
			self.buffer = buffer
			self.completion = completion
		}
	}
	
	private var bufferQueue: [WriteItem] = []
	
	func write(_ buffer: Buffer, completion: (() -> Void)? = nil) {
		queue.async {
			let writeItem = WriteItem(buffer: buffer, completion: completion)
			self.bufferQueue.append(writeItem)
			
			self.write()
		}
	}
	
	private func write() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		while output.hasSpaceAvailable {
			guard let current = bufferQueue.first else { return }
			
			print("writing: \(current.buffer.data)")
			output.write(UInt32(current.buffer.data.count + 4))
			output.write(current.buffer.data)
			current.completion?()
			
			bufferQueue.removeFirst()
		}
	}
	
	
	// MARK: - Reading
	
	private func read() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		do {
			guard input.hasBytesAvailable else { return }
			
			
			let byte: UInt8 = try input.read()
			print("command: \(byte)")
			guard let requestType = RequestType(rawValue: byte) else {
				print("unrecognized message type \(byte).")
				return
			}
			
			
			switch requestType {
			case .authentication:
				let length: UInt32 = try input.read()
				let rawResponse: UInt32 = try input.read()
				_ = input.read(Int(length - 4 - 4))
				
				if let response = AuthenticationResponse(rawValue: rawResponse) {
					switch response {
					case .authenticationOK:
						self.isAuthenticated = true
						Connection.loginSuccess.post(sender: self)
					}
				} else {
					
				}
			case .statusReport:
				let length: UInt32 = try input.read() - 4
				let data = input.read(Int(length))
				
				// split on the C style null terminating character
				let parts = data
					.split(separator: 0, maxSplits: 2, omittingEmptySubsequences: true)
					.flatMap({ String(data: Data($0), encoding: .utf8) })
				
				let key: String
				let value: String?
				if parts.count == 1 {
					key = parts[0]
					value = nil
				} else if parts.count == 2 {
					key = parts[0]
					value = parts[1]
				} else {
					throw Error.invalidStatusData
				}
				
				parameters[key] = value
				
				print("status \(key): \(value ?? "NULL")")
			case .backendKeyData:
				let length: UInt32 = try input.read()
				guard length == 12 else { throw Error.unrecognizedMessage }
				self.processID = try input.read()
				self.secretKey = try input.read()
				
				print("processID: \(processID!) secretKey: \(secretKey!)")
			}
		} catch {
			print("read error: \(error)")
		}
	}
	
	
	// MARK: - StreamDelegate
	
	public func stream(_ stream: Stream, handle eventCode: Stream.Event) {
		queue.async {
			switch eventCode {
			case Stream.Event.openCompleted:
				print("openCompleted \(stream)")
				if self.isConnected {
					Connection.connected.post(sender: self)
				}
			case Stream.Event.hasBytesAvailable:
				print("hasBytesAvailable")
				self.read()
			case Stream.Event.hasSpaceAvailable:
				print("hasSpaceAvailable")
				self.write()
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

extension Connection {
	func sendStartup(user: String, database: String?) {
		var message = Buffer()
		
		// protocol version
		message.write(3 as Int16)
		message.write(0 as Int16)
		
		message.write("user")
		message.write(user)
		
		if let database = database {
			print("database: \(database)")
			message.write("database")
			message.write(database)
		}
		
		message.write("client_encoding")
		message.write("'utf-8'")
		
		message.write("")
		
		self.write(message)
	}
}
