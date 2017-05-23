import Foundation


public protocol PostgresRepresentable {
	/// The postgres types that can be converted from. The first is the type that will be used for input.
	static var pgTypes: [OID] { get }
	
	static var supportedModes: [Field.Mode] { get }
	
	init?(pgText text: String, type: OID)
	var pgText: String? { get }
	
	init?(pgData data: DataSlice, type: OID)
	var pgData: DataSlice? { get }
}

extension PostgresRepresentable {
	public static var supportedModes: [Field.Mode] {
		return [.text]
	}
	
	public init?(pgData data: DataSlice, type: OID) {
		return nil
	}
	
	public var pgData: DataSlice? {
		return nil
	}
}

extension PostgresRepresentable where Self: LosslessStringConvertible {
	public init?(pgText text: String, type: OID) {
		self.init(text)
	}
	
	public var pgText: String? {
		return self.description
	}
}
