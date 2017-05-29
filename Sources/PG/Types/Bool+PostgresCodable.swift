import Foundation


extension Bool: PostgresCodable, PostgresTextCodable, PostgresBinaryCodable {
	public static var pgTypes: [OID] {
		return [.bool]
	}
	
	public var pgText: String? {
		if self {
			return "t"
		} else {
			return "f"
		}
	}
	
	public init(pgText text: String) {
		switch text.lowercased() {
		case "true", "yes", "on", "t", "y", "1":
			self.init(true)
		default:
			self.init(false)
		}
	}
	
	public var pgBinary: Data? {
		return Data([ self ? 1 : 0 ])
	}
	
	public init?(pgBinary data: DataSlice, type: OID) {
		// if any byte is not null
		self.init(data.contains(where: { $0 != 0 }))
	}
}
