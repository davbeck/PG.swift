import Foundation


public struct TypeParser {
	public static let `default` = TypeParser()
	
	/// The types that will be used to parse data.
	/// 
	/// Types are used in order. The first one in this array that matches the field mode (binary or text) and type id will be used to parse the data. You can change how data will be parsed by adding to or rearanging the types. For instance, to always return Int instead of specific int sizes like Int16, you can do `types.insert(Int.self, at: 0)`, which will force Int to be used before the other types.
	var types: [PostgresRepresentable.Type] = [
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
	]
	
	
	public init() {
		
	}
	
	public func parse(_ data: DataSlice, for field: Field) -> Any? {
		for type in types {
			guard type.pgTypes.contains(field.dataTypeID) else { continue }
			guard type.supportedModes.contains(field.mode) else { continue }
			
			switch field.mode {
			case .text:
				guard let text = String(data) else { return nil }
				return type.init(pgText: text, type: field.dataTypeID)
			case .binary:
				return type.init(pgData: data, type: field.dataTypeID)
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
	
	public func parse<T: PostgresRepresentable>(_ data: DataSlice, for field: Field) -> T? {
		guard T.supportedModes.contains(field.mode) else { return nil }
		guard T.pgTypes.contains(field.dataTypeID) else { return nil }
		
		switch field.mode {
		case .text:
			guard let text = String(data) else { return nil }
			return T.init(pgText: text, type: field.dataTypeID)
		case .binary:
			return T.init(pgData: data, type: field.dataTypeID)
		}
	}
}
