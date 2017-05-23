import Foundation


/// A simple wrapper around Data that writes information in Postgre specific formats.
struct WriteBuffer {
	/// The data that has been written to
	var data = Data()
	
	/// Write an Integer type to the buffer
	///
	/// The value is flipped if needed to network byte order and appended to data.
	///
	/// - Parameter value: The value to be written.
	mutating func write<T: NetworkOrderable>(_ value: T) {
		var value = value.bigEndian
		data.append(UnsafeBufferPointer(start: &value, count: 1))
	}
	
	/// Append another buffer to this buffer
	///
	/// - Parameter buffer: The other buffer to append data from.
	mutating func write(_ buffer: WriteBuffer) {
		write(buffer.data)
	}
	
	/// Append data to the buffer
	///
	/// - Parameter data: The data to append from. No transformation is made.
	mutating func write(_ data: Data) {
		self.data.append(data)
	}
	
	/// Append a string to the buffer
	///
	/// In most cases Postgre expects strings to be in the UTF8 encoding and terminated with a null byte, which is what this method does.
	///
	/// - Parameter value: The string to write from.
	mutating func write(_ value: String) {
		data.append(value.data())
		self.write(0 as Int8)
	}
}
