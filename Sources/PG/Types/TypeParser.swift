import Foundation


public struct TypeParser {
	public static let `default` = TypeParser()
	
	/// The types that will be used to parse data.
	/// 
	/// Types are used in order. The first one in this array that matches the field mode (binary or text) and type id will be used to parse the data. You can change how data will be parsed by adding to or rearanging the types. For instance, to always return Int instead of specific int sizes like Int16, you can do `types.insert(Int.self, at: 0)`, which will force Int to be used before the other types.
	var types: [PostgresCodable.Type] = [
		Int16.self,
		UInt16.self,
		Int32.self,
		UInt32.self,
		Int64.self,
		UInt64.self,
		Int.self,
		UInt.self,
		
		Bool.self,
		
		OID.self,
		
		Date.self,
		
		UUID.self,
		
		String.self,
	]
	
	
	public init() {
		
	}
	
	public func parse(_ data: DataSlice, for field: Field) -> Any? {
		for type in types {
			guard type.pgTypes.contains(field.dataTypeID) else { continue }
			
			switch field.mode {
			case .text:
				guard let type = type as? PostgresTextDecodable.Type else { continue }
				guard let text = String(data) else { return nil }
				return type.init(pgText: text, type: field.dataTypeID)
			case .binary:
				guard let type = type as? PostgresBinaryDecodable.Type else { continue }
				return type.init(pgBinary: data, type: field.dataTypeID)
			}
		}
		
		switch field.mode {
		case .text:
			guard let text = String(data) else { return nil }
			return text
		case .binary:
			return data
		}
	}
	
	public func parse<T: PostgresCodable>(_ data: DataSlice, for field: Field) -> T? {
		guard T.pgTypes.contains(field.dataTypeID) else { return nil }
		
		switch field.mode {
		case .text:
			guard let type = T.self as? PostgresTextDecodable.Type else { return nil }
			guard let text = String(data) else { return nil }
			return type.init(pgText: text, type: field.dataTypeID) as? T
		case .binary:
			guard let type = T.self as? PostgresBinaryDecodable.Type else { return nil }
			return type.init(pgBinary: data, type: field.dataTypeID) as? T
		}
	}
}
