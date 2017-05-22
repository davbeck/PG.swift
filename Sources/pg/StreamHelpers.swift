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
	func hexEncoded() -> String {
		return map { String(format: "%02hhx", $0) }.joined()
	}
	
	var slice: DataSlice {
		return self[startIndex..<endIndex]
	}
}

public typealias DataSlice = MutableRangeReplaceableRandomAccessSlice<Data>

public enum StreamError: Swift.Error {
	case notEnoughBytes
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
	func read<T: NetworkOrderable>() throws -> T {
		var value: T = T()
		let readLength = withUnsafeMutablePointer(to: &value) { (valuePointer) in
			valuePointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size, { (buffer) in
				self.read(buffer, maxLength: MemoryLayout<T>.size)
			})
		}
		
		guard readLength == MemoryLayout<T>.size else { throw StreamError.notEnoughBytes }
		
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
