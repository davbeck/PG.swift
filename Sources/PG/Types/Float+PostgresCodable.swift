extension Float: PostgresTextCodable {
	public static var pgTypes: [OID] {
		return [.float4]
	}
}

extension Double: PostgresTextCodable {
	public static var pgTypes: [OID] {
		return [.float8, .float4]
	}
}
