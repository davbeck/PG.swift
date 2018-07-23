import Foundation


/// Either a Value value or an Error
public enum Result<Value> {
	/// Success wraps a Value value
	case success(Value)
	
	/// Failure wraps an ErrorType
	case failure(Error)
	
	public init(_ capturing: () throws -> Value) {
		do {
			self = .success(try capturing())
		} catch {
			self = .failure(error)
		}
	}
	
	public init(value: Value?, error: Error?) {
		if let error = error {
			self = .failure(error)
		} else if let value = value {
			self = .success(value)
		} else {
			fatalError()
		}
	}
	
	/// Convenience tester/getter for the value
	public var value: Value? {
		switch self {
		case .success(let v): return v
		case .failure: return nil
		}
	}
	
	/// Convenience tester/getter for the error
	public var error: Error? {
		switch self {
		case .success: return nil
		case .failure(let e): return e
		}
	}
	
	/// Test whether the result is an error.
	public var isError: Bool {
		switch self {
		case .success: return false
		case .failure: return true
		}
	}
	
	/// Adapter method used to convert a Result to a value while throwing on error.
	public func unwrap() throws -> Value {
		switch self {
		case .success(let v): return v
		case .failure(let e): throw e
		}
	}
	
	/// Chains another Result to this one. In the event that this Result is a .Success, the provided transformer closure is used to generate another Result (wrapping a potentially new type). In the event that this Result is a .Failure, the next Result will have the same error as this one.
	public func flatMap<U>(_ transform: (Value) -> Result<U>) -> Result<U> {
		switch self {
		case .success(let val): return transform(val)
		case .failure(let e): return .failure(e)
		}
	}
	
	/// Chains another Result to this one. In the event that this Result is a .Success, the provided transformer closure is used to transform the value into another value (of a potentially new type) and a new Result is made from that value. In the event that this Result is a .Failure, the next Result will have the same error as this one.
	public func map<U>(_ transform: (Value) throws -> U) -> Result<U> {
		switch self {
		case .success(let val): return Result<U> { try transform(val) }
		case .failure(let e): return .failure(e)
		}
	}
}
