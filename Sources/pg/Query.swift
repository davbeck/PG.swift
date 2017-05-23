import Foundation


public final class Query {
	public enum Error: Swift.Error {
		case wrongNumberOfBindings
		case mismatchedBindingType(value: Any?, index: Int, expectedType: Any.Type?)
	}
	
	
	public final class Statement: Equatable {
		public let name: String
		public let bindingTypes: [PostgresRepresentable.Type?]
		
		fileprivate init(name: String = UUID().uuidString, bindingTypes: [PostgresRepresentable.Type?]) {
			self.name = name
			self.bindingTypes = bindingTypes
		}
		
		public static func == (_ lhs: Statement, _ rhs: Statement) -> Bool {
			return lhs === rhs
		}
	}
	
	private(set) public var statement: Statement?
	
	public var currentBindingTypes: [PostgresRepresentable.Type?] {
		return self.bindings.map({ value in
			if let value = value {
				return type(of: value)
			} else {
				// unfortunately swift doesn't keep track of nil types
				// maybe in swift 4 we can conform Optional to PostgresRepresentable when it's wrapped type is?
				return nil
			}
		})
	}
	
	/// Create and return a new prepared statement for the receiver
	///
	/// Normally a query is prepared and excecuted at the same time. However, if you have a query that gets reused often, even if it's bindings change between calls, you can optimize performance by reusing the same query and statement.
	///
	/// This method generates a statement locally, but does not prepare it with the server. Creating a statement indicates to the Client that the query should be reused. If a query has a statement set, calling `Client.exec` will automatically prepare the statement, and subsequent calls to exec on the same connection will reuse the statement. You can also implicitly prepare it using `Client.prepare`, which will call this method automatically if there is no existing statement to prepare.
	///
	/// Note that once a query has a statement set, it's binding types are locked in and an error will be thrown if you try to update them with different types.
	///
	/// - Parameter name: The name to be used for the statement on the server. Names must be uique accross connections and it is recommended that you use the default, which will generate a UUID.
	/// - Returns: The statement that was created. This is also set on the receiver.
	public func createStatement(withName name: String = UUID().uuidString) -> Statement {
		let statement = Statement(name: name, bindingTypes: self.currentBindingTypes)
		self.statement = statement
		
		return statement
	}
	
	
	public let string: String
	public private(set) var bindings: [PostgresRepresentable?]
	
	public let completed = EventEmitter<Result<QueryResult>>()
	
	public func update(bindings: [PostgresRepresentable?]) throws {
		if let statement = statement {
			guard bindings.count == statement.bindingTypes.count else { throw Error.wrongNumberOfBindings }
			
			// swift 4 should support 3 way zip
			for (index, (binding, type)) in zip(bindings.indices, zip(bindings, statement.bindingTypes)) {
				if let binding = binding, type(of: binding) != type {
					throw Error.mismatchedBindingType(value: binding, index: index, expectedType: type)
				}
			}
		}
		
		self.bindings = bindings
	}
	
	public init(_ string: String, bindings: [PostgresRepresentable?] = []) {
		self.string = string
		self.bindings = bindings
	}
	
	public convenience init(_ string: String, _ bindings: PostgresRepresentable?...) {
		self.init(string, bindings: bindings)
	}
}

extension Query: ExpressibleByStringLiteral {
	public convenience init(stringLiteral value: String) {
		self.init(value)
	}
	
	public convenience init(unicodeScalarLiteral value: String) {
		self.init(value)
	}
	
	public convenience init(extendedGraphemeClusterLiteral value: String) {
		self.init(value)
	}
}
