import Foundation


extension String: PostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.text, .varchar, .char]
	}
	
	public var pgText: String? {
		return self
	}
	
	public init?(pgText text: String, type: OID) {
		self.init(text)
	}
}
