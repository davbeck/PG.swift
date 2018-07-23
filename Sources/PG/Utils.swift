import Foundation


extension String {
	func data() -> Data {
		// utf8 is the one true encoding, and should never return have encoding issues, but if it does, allowLossyConversion will fail gracefully
		return self.data(using: .utf8, allowLossyConversion: true)!
	}
	
	public init?(_ data: Slice<Data>, encoding: String.Encoding = .utf8) {
		self.init(bytes: data, encoding: encoding)
	}
}

extension Data {
	init<T: NetworkOrderable>(bytesFrom value: T) {
		var value = value.bigEndian
		
		self.init(buffer: UnsafeBufferPointer(start: &value, count: 1))
	}
}

extension Slice where Base == Data {
	/// Access the bytes in the data.
	///
	/// This accesses the bytes directly in it's underlying data object without an additional copy.
	///
	/// - warning: The byte pointer argument should not be stored and used outside of the lifetime of the call to the closure.
	///
	/// - Parameter body: The block to call with the bytes.
	/// - Returns: The value returned by the block.
	/// - Throws: Whatever the block throws, or nothing if it is a non throwing block.
	public func withUnsafeBytes<ResultType, ContentType>(_ body: (UnsafePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
		return try self.base.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> ResultType in
			let capacity = self.count / MemoryLayout<ContentType>.size
			
			return try bytes.advanced(by: self.startIndex).withMemoryRebound(to: ContentType.self, capacity: capacity, { (reboundBytes) -> ResultType in
				return try body(reboundBytes)
			})
		}
	}
}
