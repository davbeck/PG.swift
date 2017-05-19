import XCTest
@testable import pg

class ClientTests: XCTestCase {
    func testInvalidURL() {
		do {
			_ = try Client.Config(url: URL(string: "http://someuser:somepassword@somehost:381/somedatabase")!)
			XCTFail("creating client with invalid url succeeded")
		} catch {
		}
		
		do {
			_ = try Client.Config(url: URL(string: "://someuser:somepassword@somehost:381/somedatabase")!)
			_ = try Client.Config(url: URL(string: "postgres://someuser:somepassword@somehost:381/somedatabase")!)
		} catch {
			XCTFail("creating client with valid url failed: \(error)")
		}
    }
	
	func testConnect() {
		let client = Client(Client.Config(user: "postgres", database: "truckee"))
		
		let loginExpectation = self.expectation(description: "login client")
		Client.loginSuccess.observe(object: client) { _ in
			XCTAssertTrue(client.isConnected)
			loginExpectation.fulfill()
		}
		
		let connectExpectation = self.expectation(description: "connect client")
		client.connect(completion: { error in
			XCTAssertNil(error)
			
			connectExpectation.fulfill()
		})
		
		waitForExpectations(timeout: 30)
	}


    static var allTests: [(String, (ClientTests) -> () -> Void)] = [
        ("testExample", testInvalidURL),
        ("testConnect", testConnect),
    ]
}
