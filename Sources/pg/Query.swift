import Foundation


public final class Query {
	public enum Error: Swift.Error {
		case wrongNumberOfBindings
		case mismatchedBindingType(value: Any?, index: Int, expectedType: Any.Type)
	}
	
	public let string: String
	public let bindingTypes: [Any.Type]
	public private(set) var bindings: [Any?]
	
	public let completed = EventEmitter<Result<QueryResult>>()
	
	public func update(bindings: [Any?]) throws {
		guard bindings.count == bindingTypes.count else { throw Error.wrongNumberOfBindings }
		
		// swift 4 should support 3 way zip
		for (index, (binding, type)) in zip(bindings.indices, zip(bindings, bindingTypes)) {
			if type(of: binding) != type {
				throw Error.mismatchedBindingType(value: binding, index: index, expectedType: type)
			}
		}
		
		self.bindings = bindings
	}
	
	public init(_ string: String, bindings: [Any?] = []) {
		self.string = string
		self.bindings = bindings
		self.bindingTypes = bindings.map({ type(of: $0) })
	}
	
	public convenience init(_ string: String, _ bindings: Any?...) {
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
