// Generated using Sourcery 0.8.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


import XCTest

@testable import PGTests
extension ClientTests {
  static var allTests: [(String, (ClientTests) -> () throws -> Void)] = [
    ("testInvalidURL", testInvalidURL),
    ("testCreateTable", testCreateTable),
    ("testConnect", testConnect),
    ("testSimpleQuery", testSimpleQuery),
    ("testQueryBindings", testQueryBindings),
    ("testBindingUpdate", testBindingUpdate),
    ("testPreparedStatement", testPreparedStatement),
    ("testBinaryResults", testBinaryResults),
    ("testPool", testPool)
  ]
}
extension ConnectionTests {
  static var allTests: [(String, (ConnectionTests) -> () throws -> Void)] = [
    ("testMD5", testMD5)
  ]
}
extension DateCodingTests {
  static var allTests: [(String, (DateCodingTests) -> () throws -> Void)] = [
    ("testTimestampWithoutTimezone", testTimestampWithoutTimezone),
    ("testTimestampWithTimezone", testTimestampWithTimezone)
  ]
}

// swiftlint:disable trailing_comma
XCTMain([
  testCase(ClientTests.allTests),
  testCase(ConnectionTests.allTests),
  testCase(DateCodingTests.allTests),
])
// swiftlint:enable trailing_comma

