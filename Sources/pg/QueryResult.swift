import Foundation


/// A successful result from a query excecution
public class QueryResult {
	/// A result processing error
	///
	/// - invalidCommandResponse: Thrown when commandResponse is in a format besides "COMMAND ROWS"
	/// - mismatchedRowCount: Thrown when the number of rows don't match the row count
	public enum Error: Swift.Error {
		case invalidCommandResponse
		case mismatchedRowCount(String, Int)
	}
	
	public enum Kind: String {
		case insert
		case delete
		case update
		case select
		case move
		case fetch
		case copy
		case createDatabase
		case dropDatabase
	}
	
	/// The kind of query that was excecuted
	public let kind: Kind
	
	/// Information for each field in each row
	public let fields: [Field]
	
	/// If the query was a SELECT query, contains the rows returned, or an empty array for other types of queries.
	public let rows: [Row]
	
	/// The number of rows effected by the query. For SELECT, this should be the same as `rows.count`, but for other types will be the number of rows updated, inserted or deleted.
	public let rowCount: Int
	
	/// The type parser to use to convert row data into usable types.
	public let typeParser: TypeParser
	
	init(commandResponse: String, fields: [Field], rows: [[DataSlice?]], typeParser: TypeParser) throws {
		if commandResponse == "CREATE DATABASE" {
			self.kind = .createDatabase
			self.rowCount = 1
		} else if commandResponse == "DROP DATABASE" {
			self.kind = .dropDatabase
			self.rowCount = 1
		} else {
			let responseComponents = commandResponse.components(separatedBy: " ")
			guard
				responseComponents.count >= 2,
				let kind = Kind(rawValue: responseComponents[0].lowercased()),
				let rowCount = Int(responseComponents[1])
				else { throw Error.invalidCommandResponse }
			
			if kind == .select {
				guard rowCount == rows.count else {
					throw Error.mismatchedRowCount(commandResponse, rows.count)
				}
			}
			
			self.kind = kind
			self.rowCount = rowCount
		}
		
		self.fields = fields
		self.typeParser = typeParser
		self.rows = rows.map({ Row(fields: fields, typeParser: typeParser, rawRow: $0) })
	}
	
	
	
	/// A single row in a query result.
	public struct Row {
		/// The fields info that describe the rows properties
		public let fields: [Field]
		
		/// The type parser to use to interpret row values
		public let typeParser: TypeParser
		
		/// The raw row data returned from the server
		///
		/// DataSlice references a Data object rather than copying memory for each value.
		let rawRow: [DataSlice?]
		
		
		/// Get the raw data slice for the value at a given index
		///
		/// - Parameter index: The index of the column/field to get.
		public subscript(raw index: Int) -> DataSlice? {
			get {
				return rawRow[index]
			}
		}
		
		/// Get a processed value for the value at a given index
		///
		/// Values are processed by the 'typeParser` each time this is called.
		///
		/// - Parameter index: The index of the column/field to get.
		public subscript(index: Int) -> Any? {
			get {
				guard let data = rawRow[index] else { return nil }
				let field = fields[index]
				
				return typeParser.parse(data, for: field)
			}
		}
		
		
		/// Get the raw data slice for the field with the given name
		///
		/// - Parameter name: The name of the field to fetch.
		public subscript(raw name: String) -> DataSlice? {
			guard let index = fields.index(where: { $0.name == name }) else { return nil }
			
			return rawRow[index]
		}
		
		/// Get a processed value for the field with the given name
		///
		/// Values are processed by the 'typeParser` each time this is called.
		///
		/// - Parameter name: The name of the field to fetch.
		public subscript(name: String) -> Any? {
			guard let index = fields.index(where: { $0.name == name }) else { return nil }
			
			return self[index]
		}
		
		/// Get a value for a given column as a specific type
		///
		/// some types can handle multiple postgres types (like Int for all sizes of pg ints). Using this method, it can return the result as a specific type, assuming it is compatable with the column type.
		///
		/// - Parameter name: The index of the field to fetch.
		/// - Returns: A value for the field or nil, if the value cannot be processed as type T.
		public func value<T: PostgresCodable>(at index: Int) -> T? {
			// swift 4 should introduce generic subscripts
			guard let data = rawRow[index] else { return nil }
			let field = fields[index]
			
			return typeParser.parse(data, for: field)
		}
		
		/// Get a value for a given column as a specific type
		///
		/// some types can handle multiple postgres types (like Int for all sizes of pg ints). Using this method, it can return the result as a specific type, assuming it is compatable with the column type.
		///
		/// - Parameter name: The name of the field to fetch.
		/// - Returns: A value for the field or nil, if the value cannot be processed as type T.
		public func value<T: PostgresCodable>(for name: String) -> T? {
			guard let index = fields.index(where: { $0.name == name }) else { return nil }
			
			return value(at: index)
		}
	}
}


extension Dictionary where Key == String, Value == Any {
	/// Convert a Row into a simple dictionary
	///
	/// The default types will be used for each value. The field names will be used for the key.
	///
	/// - Parameter row: The row to convert
	public init(_ row: QueryResult.Row) {
		self.init()
		
		for (index, field) in zip(row.fields.indices, row.fields) {
			self[field.name] = row[index]
		}
	}
}
