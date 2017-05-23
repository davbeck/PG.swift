import Foundation


private let timestampFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(abbreviation: "GMT")
	formatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ss.SSSSSS"
	return formatter
}()


extension Date: PostgresRepresentable {
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
	
	public init?(pgText text: String) {
		guard let date = timestampFormatter.date(from: text) else { return nil }
		self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate)
	}
}
