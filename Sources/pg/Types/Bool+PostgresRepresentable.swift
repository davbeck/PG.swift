extension Bool: PostgresRepresentable {
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
}
