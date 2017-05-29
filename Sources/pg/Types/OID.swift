import Foundation


public struct OID: RawRepresentable {
	public let rawValue: UInt32
	
	public init(rawValue: UInt32) {
		self.rawValue = rawValue
	}
	
	public init(_ rawValue: UInt32) {
		self.init(rawValue: rawValue)
	}
	
	
	public static let int8 = OID(20) // int8
	public static let int2 = OID(21) // int2
	public static let int4 = OID(23) // int4
	public static let oid = OID(26) // oid
	public static let float4 = OID(700) // float4
	public static let float8 = OID(701) // float8
	public static let bool = OID(16) // bool
	
	public static let text = OID(25) // text
	public static let varchar = OID(1043) // varchar
	public static let bpchar = OID(1042) // bpchar
	
	public static let date = OID(1082) // date
	public static let timestamp = OID(1114) // timestamp without timezone
	public static let timestampWithTimezone = OID(1184) // timestamp with timezone
	
	public static let uuid = OID(2950) // uuid
	
	public static let point = OID(600) // point
	public static let circle = OID(718) // circle
	
	public static let cidrArray = OID(651) // cidr[]
	public static let boolArray = OID(1000) // bool array
	public static let byteAArray = OID(1001) // ByteAArray
	public static let int2Array = OID(1005) // _int2
	public static let int4Array = OID(1007) // _int4
	public static let oidArray = OID(1028) // oid[]
	public static let int8Array = OID(1016) // _int8
	public static let pointArray = OID(1017) // point[]
	public static let float4Array = OID(1021) // _float4
	public static let float8Array = OID(1022) // _float8
	public static let numericArray = OID(1231) // _numeric
	public static let regprocArray = OID(1008) // _regproc
	public static let textArray = OID(1009) // _text
	public static let varcharArray = OID(1015) // _varchar
	public static let charArray = OID(1014) // _char
	public static let macaddrArray = OID(1040) // macaddr[]
	public static let inetArray = OID(1041) // inet[]
	public static let timestampArray = OID(1115) // timestamp without time zone[]
	public static let dateArray = OID(1182) // _date
	public static let timestampWithTimeZoneArray = OID(1185) // timestamp with time zone[]
	public static let moneyArray = OID(791) // money[]
	public static let timeArray = OID(1183) // time[]
	public static let timetzArray = OID(1270) // timetz[]
	public static let uuidArray = OID(2951) // uuid[]
	
	public static let interval = OID(1186) // Interval
	public static let byteA = OID(17) // ByteA
	
	public static let json = OID(114) // json
	public static let jsonb = OID(3802) // jsonb
	
	public static let jsonArray = OID(199) // json[]
	public static let jsonbArray = OID(3807) // jsonb[]
	
	public static let numrangeArray = OID(3907) // numrange[]
}

extension OID: Hashable {
	public static func == (_ lhs: OID, _ rhs: OID) -> Bool {
		return lhs.rawValue == rhs.rawValue
	}
	
	public var hashValue: Int {
		return rawValue.hashValue
	}
}

extension OID: ExpressibleByIntegerLiteral {
	public init(integerLiteral value: UInt32) {
		self.init(value)
	}
}

extension OID: PostgresTextCodable, PostgresBinaryCodable {
	public static var pgTypes: [OID] {
		return [.oid]
	}
	
	public init?(pgText text: String, type: OID) {
		guard let rawValue = UInt32(text) else { return nil }
		self.init(rawValue)
	}
	
	public var pgText: String? {
		return rawValue.pgText
	}
	
	public init?(pgBinary data: DataSlice, type: OID) {
		guard let rawValue = UInt32(pgBinary: data, type: type) else { return nil }
		self.init(rawValue)
	}
	
	public var pgBinary: Data? {
		return rawValue.pgBinary
	}
}
