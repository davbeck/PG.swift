import Foundation


private let timestampFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(abbreviation: "GMT")
	formatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ss.SSSSSS"
	return formatter
}()

private let dateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(abbreviation: "GMT")
	formatter.dateFormat = "yyyy-MM-dd"
	return formatter
}()


extension Date: PostgresRepresentable {
	public static var pgTypes: [OID] {
		return [
			.timestamp,
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
		default:
			return nil
		}
		
		if let date = date {
			self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate)
		} else {
			return nil
		}
	}
}
