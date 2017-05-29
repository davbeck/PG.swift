import Foundation


public protocol PostgresCodable {
	/// The postgres types that can be converted from. The first is the type that will be used for input.
	static var pgTypes: [OID] { get }
}


public protocol PostgresTextEncodable: PostgresCodable {
	var pgText: String? { get }
}

public protocol PostgresTextDecodable: PostgresCodable {
	init?(pgText text: String, type: OID)
}

public typealias PostgresTextCodable = PostgresTextEncodable & PostgresTextDecodable


public protocol PostgresBinaryEncodable: PostgresCodable {
	var pgBinary: Data? { get }
}

public protocol PostgresBinaryDecodable: PostgresCodable {
	init?(pgBinary data: DataSlice, type: OID)
}

public typealias PostgresBinaryCodable = PostgresBinaryEncodable & PostgresBinaryDecodable


extension PostgresTextEncodable where Self: LosslessStringConvertible {
	public var pgText: String? {
		return self.description
	}
}

extension PostgresTextDecodable where Self: LosslessStringConvertible {
	public init?(pgText text: String, type: OID) {
		self.init(text)
	}
}
