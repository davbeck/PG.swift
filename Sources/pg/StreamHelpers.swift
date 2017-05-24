import Foundation


extension String {
	func data() -> Data {
		// utf8 is the one true encoding, and should never return have encoding issues, but if it does, allowLossyConversion will fail gracefully
		return self.data(using: .utf8, allowLossyConversion: true)!
	}
	
	public init?(_ data: DataSlice, encoding: String.Encoding = .utf8) {
		self.init(bytes: data, encoding: encoding)
	}
}

extension Data {
	init<T: NetworkOrderable>(bytesFrom value: T) {
		var value = value.bigEndian
		
		self.init(buffer: UnsafeBufferPointer(start: &value, count: 1))
	}
}

public typealias DataSlice = MutableRangeReplaceableRandomAccessSlice<Data>
