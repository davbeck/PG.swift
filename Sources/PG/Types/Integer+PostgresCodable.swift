import Foundation


public protocol IntegerPostgresCodable: PostgresTextCodable, PostgresBinaryCodable, Integer, CustomStringConvertible {
	init?(_ text: String, radix: Int)
}

extension IntegerPostgresCodable {
	public init?(pgText text: String, type: OID) {
		self.init(text, radix: 10)
	}
}

extension PostgresTextDecodable where Self: SignedInteger {
	public var pgText: String? {
		return String.init(self)
	}
}

extension PostgresTextDecodable where Self: UnsignedInteger {
	public var pgText: String? {
		return String.init(self)
	}
}

extension PostgresBinaryDecodable where Self: NetworkOrderable {
	public init?(pgBinary data: DataSlice, type: OID) {
		guard data.count == MemoryLayout<Self>.size else { return nil }
		self.init(bigEndian: data.withUnsafeBytes({ $0.pointee }))
	}
}

extension PostgresBinaryEncodable where Self: NetworkOrderable {
	public var pgBinary: Data? {
		var value = self.bigEndian
		return withUnsafeBytes(of: &value, { Data($0) })
	}
}


extension Int16: IntegerPostgresCodable {
	public static var pgTypes: [OID] {
		return [.int2]
	}
}

extension UInt16: IntegerPostgresCodable {
	public static var pgTypes: [OID] {
		return [.int2]
	}
}


extension Int32: IntegerPostgresCodable {
	public static var pgTypes: [OID] {
		return [.int4]
	}
}

extension UInt32: IntegerPostgresCodable {
	public static var pgTypes: [OID] {
		return [.int4]
	}
}


extension Int64: IntegerPostgresCodable {
	public static var pgTypes: [OID] {
		return [.int8]
	}
}

extension UInt64: IntegerPostgresCodable {
	public static var pgTypes: [OID] {
		return [.int8]
	}
}


extension Int: IntegerPostgresCodable {
	public static var pgTypes: [OID] {
		return [.int8, .int4, .int2]
	}
	
	public init?(pgBinary data: DataSlice, type: OID) {
		switch data.count {
		case 8:
			self.init(Int64(pgBinary: data, type: type) ?? 0)
		case 4:
			self.init(Int64(pgBinary: data, type: type) ?? 0)
		case 2:
			self.init(Int64(pgBinary: data, type: type) ?? 0)
		default:
			return nil
		}
	}
	
	public var pgBinary: Data? {
		var value = self.bigEndian
		return withUnsafeBytes(of: &value, { Data($0) })
	}
}

extension UInt: IntegerPostgresCodable {
	public static var pgTypes: [OID] {
		return [.int8, .int4, .int2]
	}
	
	public init?(pgBinary data: DataSlice, type: OID) {
		switch data.count {
		case 8:
			self.init(UInt64(pgBinary: data, type: type) ?? 0)
		case 4:
			self.init(UInt64(pgBinary: data, type: type) ?? 0)
		case 2:
			self.init(UInt64(pgBinary: data, type: type) ?? 0)
		default:
			return nil
		}
	}
	
	public var pgBinary: Data? {
		var value = self.bigEndian
		return withUnsafeBytes(of: &value, { Data($0) })
	}
}
