import Foundation


extension Connection {
	/// Outgoing/frontend message types
	///
	/// Postgre messages (almost) always start with a single byte indicating what type of message they are. The documentation refer to these by their ASCII character. The rawValue is the ASCII code point.
	///
	/// See https://www.postgresql.org/docs/devel/static/protocol-message-formats.html.
	public struct FrontendMessageType: RawRepresentable, CustomDebugStringConvertible, ExpressibleByIntegerLiteral, Hashable {
		public let rawValue: UInt8
		
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
		
		public init(integerLiteral value: UInt8) {
			self.rawValue = value
		}
		
		public static func == (_ lhs: FrontendMessageType, _ rhs: FrontendMessageType) -> Bool {
			return lhs.rawValue == rhs.rawValue
		}
		
		public var hashValue: Int {
			return rawValue.hashValue
		}
		
		
		public static let startup: FrontendMessageType = 0 // the only message that doesn't announce it's type
		
		public static let simpleQuery: FrontendMessageType = 81 // Q
		public static let parseQuery: FrontendMessageType = 80 // P
		public static let bind: FrontendMessageType = 66 // B
		public static let describe: FrontendMessageType = 68 // D
		public static let execute: FrontendMessageType = 69 // E
		
		public static let sync: FrontendMessageType = 83 // S
		
		
		public var debugDescription: String {
			let character = Character(UnicodeScalar(self.rawValue))
			
			return "PG.Connection.BackendMessageType(\(character) / \(self.rawValue))"
		}
	}
	
	
	/// An outgoing message to the server
	///
	/// Represents a single message packet to the server, which includes a type (except for startup) and the size of the data being sent, followed by the payload of the packet.
	public struct FrontendMessage {
		public let type: FrontendMessageType
		
		/// The data that has been written to
		private(set) public var data: Data
		
		private var sizeOffset: Int {
			return type == .startup ? 0 : 1
		}
		
		
		/// Create a new message
		///
		/// - Parameters:
		///   - type: The type of the message.
		///   - capacity: The initial capacity of the data to be written, not including the type and size header.
		public init(_ type: FrontendMessageType, capacity: Int = 0) {
			let headerSize = type == .startup ? 4 : 5
			
			self.type = type
			self.data = Data(capacity: capacity + headerSize)
			
			if type != .startup {
				self.write(type.rawValue)
			}
			
			// reserve the space for the size part of the header
			self.write(UInt32(0))
		}
		
		private mutating func writeHeader() {
			data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
				bytes.advanced(by: self.sizeOffset).withMemoryRebound(to: UInt32.self, capacity: 1, { (sizeBytes) -> Void in
					sizeBytes.pointee = UInt32(self.data.count - self.sizeOffset).bigEndian
				})
			}
		}
		
		/// Write an Integer type to the buffer
		///
		/// The value is flipped if needed to network byte order and appended to data.
		///
		/// - Parameter value: The value to be written.
		public mutating func write<T: NetworkOrderable>(_ value: T) {
			var value = value.bigEndian
			data.append(UnsafeBufferPointer(start: &value, count: 1))
			
			writeHeader()
		}
		
		/// Append data to the buffer
		///
		/// - Parameter data: The data to append from. No transformation is made.
		public mutating func write(_ data: Data) {
			self.data.append(data)
			
			writeHeader()
		}
		
		/// Append a string to the buffer
		///
		/// In most cases Postgre expects strings to be in the UTF8 encoding and terminated with a null byte, which is what this method does.
		///
		/// - Parameter value: The string to write from.
		public mutating func write(_ value: String) {
			data.append(value.data())
			self.write(0 as Int8)
			
			writeHeader()
		}
	}
	
	
	/// Writes a message to the socket
	///
	/// - Parameter message: The message
	public func send(_ message: FrontendMessage) {
		print("sending \(message)")
		self.socket.write(data: message.data) { error in
			if let error = error {
				self.error.emit(error)
			}
		}
	}
}
