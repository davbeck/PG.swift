import Foundation


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
	
	mutating func write(_ buffer: Buffer) {
		write(buffer.data)
	}
	
	mutating func write(_ data: Data) {
		self.data.append(data)
	}
	
	mutating func write(_ value: String) {
		data.append(value.data())
		self.write(0 as Int8)
	}
}
