import Foundation


public struct TypeParser {
	public typealias TypeID = UInt32
	public typealias TextParser = (String) -> Any?
	public typealias BinaryParser = (DataSlice) -> Any?
	
	public static let `default` = TypeParser()
	
	var textParsers: [UInt32:TextParser] = [:]
	var binaryParsers: [UInt32:BinaryParser] = [:]
	
	public init() {
		
	}
	
	public func parse(_ data: DataSlice, for field: Field) -> Any? {
		switch field.mode {
		case .text:
			if let parser = textParsers[field.dataTypeID] {
				guard let text = String(data) else { return nil }
				return parser(text)
			} else {
				return parseText(data, withOID: field.dataTypeID)
			}
		case .binary:
			return binaryParsers[field.dataTypeID]?(data)
		}
	}
	
	
	private static let timestampFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(abbreviation: "GMT")
		formatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ss.SSSSSS"
		return formatter
	}()
	
	
	public func parseText(_ data: DataSlice, withOID oid: UInt32) -> Any? {
		guard let text = String(data) else { return nil }
		
		switch oid {
		case 20: // int8
			return Int64(text)
		case 21: // int2
			return Int16(text)
		case 23, 26: // int4, oid
			return Int32(text)
		case 700: // float4
			return Float(text)
		case 701: // float8
			return Double(text)
		case 16: // biik
			switch text {
			case "TRUE", "true", "yes", "on", "t", "y", "1":
				return true
			default:
				return false
			}
			
		// dates and times
		// TODO: handle non ISO formats
		case 1082: // date
			return text
		case 1114: // timestamp without timezone
			return TypeParser.timestampFormatter.date(from: text)
		case 1184: // timestamp with timezone
			return text
			
		case 600: // point
			return text
		case 718: // circle
			return text
			
		case 2950:
			return UUID(uuidString: text)
			
		// arrays
		case 651: // cidr[]
			return text
		case 1000: // bool array
			return text
		case 1001: // ByteAArray
			return text
		case 1005: // _int2
			return text
		case 1007: // _int4
			return text
		case 1028: // oid[]
			return text
		case 1016: // _int8
			return text
		case 1017: // point[]
			return text
		case 1021: // _float4
			return text
		case 1022: // _float8
			return text
		case 1231: // _numeric
			return text
		case 1014: // char
			return text
		case 1015: // varchar
			return text
		case 1008: // _regproc
			return text
		case 1009: // _text
			return text
		case 1040: // macaddr[]
			return text
		case 1041: // inet[]
			return text
		case 1115: // timestamp without time zone[]
			return text
		case 1182: // _date
			return text
		case 1185: // timestamp with time zone[]
			return text
		case 791: // money[]
			return text
		case 1183: // time[]
			return text
		case 1270: // timetz[]
			return text
		case 2951: // uuid[]
			return text
			
		case 1186: // Interval
			return text
		case 17: // ByteA
			return text
			
		case 114: // json
			return text
		case 3802: // jsonb
			return text

		case 199: // json[]
			return text
		case 3807: // jsonb[]
			return text
			
		case 3907: // numrange[]
			return text
			
			
		default:
			return text
		}
	}
}
