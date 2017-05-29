import Foundation


private let timestampFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(abbreviation: "GMT")
	formatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ss.SSSSSS"
	return formatter
}()

private let timestamptzFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(abbreviation: "GMT")
	formatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ss.SSSSSSZ"
	return formatter
}()

private let dateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(abbreviation: "GMT")
	formatter.dateFormat = "yyyy-MM-dd"
	return formatter
}()

private let pgOffsetFrom1970: TimeInterval = 946684800


extension Date: PostgresCodable, PostgresTextCodable, PostgresBinaryCodable {
	public static var pgTypes: [OID] {
		return [
			.timestamp,
			.timestampWithTimezone,
			.date,
		]
	}
	
	public var pgText: String? {
		return timestampFormatter.string(from: self)
	}
	
	public init?(pgText text: String, type: OID) {
		let date: Date?
		
		switch type {
		case OID.date:
			date = dateFormatter.date(from: text)
		case OID.timestamp:
			date = timestampFormatter.date(from: text)
		case OID.timestampWithTimezone:
			// postgres uses 2 digit timezones 🙄 which DateFormatter doesn't support
			// what happens if you try to use a timezone from one of those weird half hour offset timezones 🤷🏼‍♂️
			date = timestamptzFormatter.date(from: text + "00")
		default:
			return nil
		}
		
		if let date = date {
			self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate)
		} else {
			return nil
		}
	}
	
	public init?(pgBinary data: DataSlice, type: OID) {
		if data.count == 8 {
			let rawValue = TimeInterval(Int64(bigEndian: data.withUnsafeBytes({ $0.pointee })))
			// Adjust from 2000 to 1970 (Foundation reference date is 2001 and theoretically subject to change)
			self.init(timeIntervalSince1970: (rawValue / 1000 / 1000) + pgOffsetFrom1970)
		} else {
			return nil
		}
	}
	
	public var pgBinary: Data? {
		var rawValue = Int64((self.timeIntervalSince1970 - pgOffsetFrom1970) * 1000 * 1000).bigEndian
		
		return withUnsafeBytes(of: &rawValue, { Data($0) })
	}
}
