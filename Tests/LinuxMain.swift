import XCTest
@testable import PGTests

XCTMain([
    testCase(ClientTests.allTests),
    testCase(TypeParserTests.allTests),
])
