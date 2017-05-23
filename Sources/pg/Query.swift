import Foundation


public final class Query {
	public enum Error: Swift.Error {
		case wrongNumberOfBindings
		case mismatchedBindingType(value: Any?, index: Int, expectedType: Any.Type?)
	}
	
	
	public final class Statement {
		public let name: String
		public let bindingTypes: [PostgresRepresentable.Type?]
		
		init(name: String = UUID().uuidString, bindingTypes: [PostgresRepresentable.Type?]) {
			self.name = name
			self.bindingTypes = bindingTypes
		}
	}
	
	public var statement: Statement?
	
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
