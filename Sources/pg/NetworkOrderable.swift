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
