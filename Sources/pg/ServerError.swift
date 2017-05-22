import Foundation


public struct ServerError: Swift.Error {
	public enum Field: UInt8 {
		case localizedSeverity = 83 // S
		case severity = 86 // V
		case sqlState = 67 // C
		case message = 77 // M
		case detail = 68 // D
		case hint = 72 // H
		case position = 80 // P
		case internalPosition = 112 // p
		case context = 87 // W
		case schemaName = 115 // s
		case tableName = 116 // t
		case columnName = 99 // c
		case dataTypeName = 100 // d
		case constraintName = 110 // n
		case file = 70 // F
		case line = 76 // L
		case routine = 82 // R
	}
	
	internal(set) public var info: [(Field, String)]
	
	internal init() {
		info = []
	}
	
	
	public subscript(field: Field) -> [String] {
		return info.lazy.filter({ $0.0 == field }).map({ $0.1 })
	}
	
	
	var localizedSeverity: String? {
		return self[.localizedSeverity].first ?? self[.severity].first
	}
}


extension ServerError: LocalizedError {
	/// A localized message describing what error occurred.
	public var errorDescription: String? {
		return self[.message].joined(separator: "/n")
	}
	
	/// A localized message describing the reason for the failure.
	public var failureReason: String? {
		return self[.detail].joined(separator: "/n")
	}
	
	/// A localized message describing how one might recover from the failure.
	public var recoverySuggestion: String? {
		return self[.hint].joined(separator: "/n")
	}
}
