import Foundation


extension Connection {
	/// Incoming/backend message types
	///
	/// Postgre messages (almost) always start with a single byte indicating what type of message they are. The documentation refer to these by their ASCII character. The rawValue is the ASCII code point.
	///
	/// See https://www.postgresql.org/docs/devel/static/protocol-message-formats.html.
	public struct BackendMessageType: RawRepresentable, ExpressibleByIntegerLiteral, Hashable {
		public let rawValue: UInt8
		
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
		
		public init(integerLiteral value: UInt8) {
			self.rawValue = value
		}
		
		public static func == (_ lhs: BackendMessageType, _ rhs: BackendMessageType) -> Bool {
			return lhs.rawValue == rhs.rawValue
		}
		
		public var hashValue: Int {
			return rawValue.hashValue
		}
		
		
		public static let authentication: BackendMessageType = 82 // R
		public static let statusReport: BackendMessageType = 83 // S
		public static let backendKeyData: BackendMessageType = 75 // K
		public static let readyForQuery: BackendMessageType = 90 // Z
		public static let rowDescription: BackendMessageType = 84 // T
		public static let commandComplete: BackendMessageType = 67 // C
		public static let dataRow: BackendMessageType = 68 // D
		
		public static let parseComplete: BackendMessageType = 49 // 1
		public static let bindComplete: BackendMessageType = 50 // 2
		
		public static let errorResponse: BackendMessageType = 69 // E
	}
	
	
	
	/// Represents an incoming message from the server
	///
	/// The connection parses messages as they come in and tries to parse them from there.
	public struct BackendMessage {
		public enum Error: Swift.Error {
			case missingStringNullTerminator
			case invalidStringData
			case notEnoughData
		}
		
		
		/// The type of the message, read from the first byte of the packet
		public var type: BackendMessageType
		
		/// The main body of the message, defined by the length in the header
		private(set) var data: DataSlice
		
		
		/// Create a new backend message
		///
		/// - Parameters:
		///   - type: The type of the message
		///   - data: The body of the message, not including the header
		public init(type: BackendMessageType, data: Data) {
			self.type = type
			self.data = DataSlice(data)
		}
		
		
		/// Read a chunk of memory from the beginning of the current data
		///
		/// Removes the data from the beginning of the current data. Subsequent reads will start at the byte following length.
		///
		/// - Parameter length: The length of data to read in bytes
		/// - Returns: A data slice from the original packet
		/// - Throws: Error.notEnoughData if the length is greater than the amount of data left to read
		public mutating func read(length: Int) throws -> DataSlice {
			guard data.count >= length else { throw Error.notEnoughData }
			
			let subData = data.prefix(length)
			
			data = data.suffix(from: subData.endIndex)
			
			return subData
		}
		
		/// Read an integer of a certain size from the beginning of the current data
		///
		/// - Returns: An integer of type T
		/// - Throws: Error.notEnoughData if the length is greater than the amount of data left to read
		public mutating func read<T: NetworkOrderable>() throws -> T {
			let subData = try self.read(length: MemoryLayout<T>.size)
			let value: T = subData.withUnsafeBytes({ $0.pointee })
			
			data = data.suffix(from: subData.endIndex)
			
			return T(bigEndian: value)
		}
		
		/// Read a null terminated string from the beginning of the current data
		///
		/// Normally strings returned by the server will be null terminated, like a C string (although the body can still be encoded using something like UTF8).
		///
		/// - Returns: A new string
		/// - Throws: Error
		public mutating func read() throws -> String {
			guard let terminatorIndex = data.index(of: 0) else { throw Error.missingStringNullTerminator }
			
			let subData = data.prefix(upTo: terminatorIndex)
			
			data = data.suffix(from: subData.endIndex + 1) // +1 for null character itself
			
			guard let string = String(subData) else { throw Error.invalidStringData }
			return string
		}
	}
}
