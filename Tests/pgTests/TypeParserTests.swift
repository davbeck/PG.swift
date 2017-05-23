import XCTest
@testable import PG

class TypeParserTests: XCTestCase {
	func testTimestampWithoutTimezone() {
		let result = Date(pgText: "2017-05-19 16:37:46.398991")

		XCTAssertEqual(result, Date(timeIntervalSince1970: 1495211866.398))
	}
	
	
	static var allTests: [(String, (TypeParserTests) -> () -> Void)] = [
		("testTimestampWithoutTimezone", testTimestampWithoutTimezone),
		]
}
