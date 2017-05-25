import Foundation


/// A value that can be converted to network byte order (big endian)
public protocol NetworkOrderable {
	init()
	init(bigEndian value: Self)
	var bigEndian: Self { get }
}

extension Int8: NetworkOrderable {
	public init(bigEndian value: Int8) {
		self.init(value)
	}
	
	public var bigEndian: Int8 {
		return self
	}
}
extension UInt8: NetworkOrderable {
	public init(bigEndian value: UInt8) {
		self.init(value)
	}
	
	public var bigEndian: UInt8 {
		return self
	}
}

extension Int16: NetworkOrderable {}
extension UInt16: NetworkOrderable {}
extension Int32: NetworkOrderable {}
extension UInt32: NetworkOrderable {}
extension Int64: NetworkOrderable {}
extension UInt64: NetworkOrderable {}
