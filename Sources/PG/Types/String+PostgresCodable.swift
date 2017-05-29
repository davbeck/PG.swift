import Foundation


extension String: PostgresTextCodable, PostgresBinaryCodable {
	public static var pgTypes: [OID] {
		return [.text, .varchar, .bpchar]
	}
	
	public init?(pgText text: String, type: OID) {
		self.init(text)
	}
	
	public var pgText: String? {
		return self
	}
	
	public init?(pgBinary data: DataSlice, type: OID) {
		self.init(data)
	}
	
	public var pgBinary: Data? {
		return self.data()
	}
}
