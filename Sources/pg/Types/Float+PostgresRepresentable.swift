extension Float: PostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.float4]
	}
}

extension Double: PostgresRepresentable {
	public static var pgTypes: [OID] {
		return [.float8, .float4]
	}
}
