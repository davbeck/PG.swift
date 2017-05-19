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
	func read<T: NetworkOrderable>() -> T? {
		var value: T = T()
		let readLength = withUnsafeMutablePointer(to: &value) { (valuePointer) in
			valuePointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size, { (buffer) in
				self.read(buffer, maxLength: MemoryLayout<T>.size)
			})
		}
		guard readLength == MemoryLayout<T>.size else { return nil }
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
	enum RequestType: UInt8 {
		case authentication = 82 // ASCII R
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
	
	public var isAuthenticated: Bool = false
	
	
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
		
		guard input.hasBytesAvailable else { return }
		
		
		guard let byte: UInt8 = input.read() else { return }
		print("command: \(byte)")
		guard let requestType = RequestType(rawValue: byte) else { return }
		
		
		switch requestType {
		case .authentication:
			guard let length: UInt32 = input.read() else { return }
			print("length: \(length)")
			guard let rawResponse: UInt32 = input.read() else { return }
			let data = input.read(Int(length - 4 - 4))
			print("data: \(data.hexEncoded())")
			
			if let response = AuthenticationResponse(rawValue: rawResponse) {
				switch response {
				case .authenticationOK:
					self.isAuthenticated = true
					Connection.loginSuccess.post(sender: self)
				}
			} else {
				
			}
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
