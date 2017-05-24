import Foundation


/// A wrapper around Data that sequentially reads it, using postgres specific decoding.
struct ReadBuffer {
	enum Error: Swift.Error {
		case missingStringNullTerminator
		case invalidStringData
	}
	
	
	private(set) var data: DataSlice
	
	init(_ data: Data) {
		self.data = DataSlice(data)
	}
	
	
	mutating func read(length: Int) throws -> DataSlice {
		let subData = data.prefix(length)
		
		data = data.suffix(from: subData.endIndex)
		
		return subData
	}
	
	mutating func read(length: Int) throws -> Data {
		return try Data(read(length: length) as DataSlice)
	}
	
	mutating func read<T: NetworkOrderable>() throws -> T {
		let subData = data.prefix(MemoryLayout<T>.size)
		let value: T = Data(subData).withUnsafeBytes({ $0.pointee })
		
		data = data.suffix(from: subData.endIndex)
		
		return T(bigEndian: value)
	}
	
	mutating func read() throws -> String {
		guard let terminatorIndex = data.index(of: 0) else { throw Error.missingStringNullTerminator }
		
		let subData = data.prefix(upTo: terminatorIndex)
		
		data = data.suffix(from: subData.endIndex + 1) // +1 for null character itself
		
		guard let string = String(subData) else { throw Error.invalidStringData }
		return string
	}
}
