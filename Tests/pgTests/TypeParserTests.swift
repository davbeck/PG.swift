import XCTest
@testable import PG

class TypeParserTests: XCTestCase {
	func testTimestampWithoutTimezone() {
		let result = TypeParser.default.parseText("2017-05-19 16:37:46.398991".data().slice, withOID: 1114) as? Date

		XCTAssertEqual(result, Date(timeIntervalSince1970: 1495211866.398))
	}
	
	
	static var allTests: [(String, (TypeParserTests) -> () -> Void)] = [
		("testTimestampWithoutTimezone", testTimestampWithoutTimezone),
		]
}
