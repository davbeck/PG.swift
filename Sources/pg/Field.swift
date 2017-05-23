import Foundation


/// A query result column info
public final class Field {
	/// The mode that the field should be interpreted with
	///
	/// - text: The default representation. The row data represents text data that then must be further transformed into other types.
	/// - binary: Row data should be directly transformed from the binary data.
	public enum Mode: UInt16 {
		case text = 0
		case binary = 1
	}
	
	/// The name of the column or generated field
	public var name: String = ""
	
	/// The id of the table, or 0 if the field is not tied to a table
	public var tableID: UInt32 = 0
	
	/// The column id, or 0  if the field is not tied to a table column
	public var columnID: UInt16 = 0
	
	
	/// The id of the type of data in the field
	///
	/// See "SELECT oid, typname FROM pg_type;" for a list of type ids.
	public var dataTypeID: OID = 0
	
	/// The data type size (see `pg_type.typlen`). Note that negative values denote variable-width types.
	public var dataTypeSize: Int16 = 0
	
	/// The type modifier (see `pg_attribute.atttypmod`). The meaning of the modifier is type-specific.
	public var dataTypeModifier: UInt32 = 0
	
	/// The format code being used for the field. In a RowDescription returned from the statement variant of Describe, the format code is not yet known and will always be zero.
	public var mode: Mode = .text
	
	
	/// Create a new Field with default values
	public init() {
		
	}
}


extension Field: CustomDebugStringConvertible {
	public var debugDescription: String {
		return "<PG.Field name=\(name), dataTypeID=\(dataTypeID), dataTypeSize=\(dataTypeSize), dataTypeModifier=\(dataTypeModifier), mode=\(mode)>"
	}
}
