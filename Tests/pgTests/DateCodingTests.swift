import Foundation
import XCTest
@testable import PG


func XCTAssertEqualDates(_ expression1: Date?, _ expression2: Date?, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
	guard let lhs = expression1, let rhs = expression2 else {
		// check if both are nil
		XCTAssert(expression1 == expression2, message, file: file, line: line)
		return
	}
	
	let difference = abs(lhs.timeIntervalSince1970.distance(to: rhs.timeIntervalSince1970))
	
	XCTAssert(difference < 0.01, message, file: file, line: line)
}


class DateCodingTests: XCTestCase {
	func testTimestampWithoutTimezone() {
		XCTAssertEqualDates(
			Date(pgText: "2017-05-19 16:37:46.39800", type: .timestamp),
			Date(timeIntervalSince1970: 1495211866.398)
		)
		
		XCTAssertEqual(
			Date(timeIntervalSince1970: 1495211866.398).pgText,
			"2017-05-19 16:37:46.398000"
		)
		
		XCTAssertEqualDates(
			Date(pgBinary: DataSlice(Data(base64Encoded: "AAHzHRMD4Ic=")!), type: .timestamp),
			Date(timeIntervalSince1970: 1495465975.333)
		)
		
		XCTAssertEqual(
			Date(timeIntervalSince1970: 1495465975.333).pgBinary,
			Data(base64Encoded: "AAHzHRMD4Ic=")
		)
	}
	
	func testTimestampWithTimezone() {
		XCTAssertEqual(
			Date(pgText: "2017-05-19 16:37:46.398991-07", type: .timestampWithTimezone),
			Date(timeIntervalSince1970: 1495237066.398)
		)
	}
}
