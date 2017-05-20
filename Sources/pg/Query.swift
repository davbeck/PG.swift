import Foundation


public final class Query {
	let string: String
	let completed = EventEmitter<Result>()
	
	init(_ string: String) {
		self.string = string
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
