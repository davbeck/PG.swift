import XCTest
@testable import PG


class ConnectionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
    
    func testMD5() {
		let username = "me"
		let password = "secret"
		let salt = Slice<Data>(Data([0xde, 0xad, 0xbe, 0xef]))
		
		let result = Connection.md5AuthenticationResponse(username: username, password: password, salt: salt)
		
        XCTAssertEqual(result, "md54126c9389903905008bcf46cb62308e4")
    }
}
