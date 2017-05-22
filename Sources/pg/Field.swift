import Foundation


public final class Field {
	public enum Mode: UInt16 {
		case text = 0
		case binary = 1
	}
	
	public var name: String = ""
	
	public var tableID: UInt32 = 0
	public var columnID: UInt16 = 0
	
	public var dataTypeID: UInt32 = 0
	public var dataTypeSize: Int16 = 0
	public var dataTypeModifier: UInt32 = 0
	
	public var mode: Mode = .text
	
	public init() {
		
	}
}


extension Field: CustomDebugStringConvertible {
	public var debugDescription: String {
		return "<PG.Field name=\(name), dataTypeID=\(dataTypeID), dataTypeSize=\(dataTypeSize), dataTypeModifier=\(dataTypeModifier), mode=\(mode)>"
	}
}
