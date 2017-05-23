import Foundation


public protocol IntegerPostgresRepresentable: PostgresRepresentable, Integer, CustomStringConvertible {
	init?(_ text: String, radix: Int)
}

extension IntegerPostgresRepresentable {
	public init?(pgText text: String) {
		self.init(text, radix: 10)
	}
}

extension PostgresRepresentable where Self: SignedInteger {
	public var pgText: String? {
		return String.init(self)
	}
}

extension PostgresRepresentable where Self: UnsignedInteger {
	public var pgText: String? {
		return String.init(self)
	}
}


extension Int16: IntegerPostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.int2]
	}
}

extension UInt16: IntegerPostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.int2]
	}
}


extension Int32: IntegerPostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.int4, .int2]
	}
}

extension UInt32: IntegerPostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.int4, .int2]
	}
}


extension Int64: IntegerPostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.int8, .int4, .int2]
	}
}

extension UInt64: IntegerPostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.int8, .int4, .int2]
	}
}


extension Int: IntegerPostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.int8, .int4, .int2]
	}
}

extension UInt: IntegerPostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.int8, .int4, .int2]
	}
}
