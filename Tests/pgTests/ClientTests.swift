import XCTest
@testable import PG

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
		client.loginSuccess.once() {
			XCTAssertTrue(client.isConnected)
			loginExpectation.fulfill()
		}
		
		let connectExpectation = self.expectation(description: "connect client")
		client.connect(completion: { error in
			XCTAssertNil(error)
			
			client.connection!.readyForQuery.once() { transactionStatus in
				XCTAssertEqual(transactionStatus, .idle)
				XCTAssertEqual(client.connection?.transactionStatus, .idle)
				
				connectExpectation.fulfill()
			}
		})
		
		waitForExpectations(timeout: 5)
	}
	
	func testClientQuery() {
		let client = Client(Client.Config(user: "postgres", database: "truckee"))
		
		let expectation = self.expectation(description: "query")
		
		client.connect() { _ in
			client.exec("SELECT * FROM posts;") { result in
				XCTAssertEqual(result.fields.count, 4)
				XCTAssertEqual(result.rows.count, 2)
				XCTAssertEqual(result.rowCount, 2)
				
				let array = Array(result.rows.map({ Dictionary($0) }))
				print("array: \(array)")
				
				expectation.fulfill()
			}
		}
		
		waitForExpectations(timeout: 5)
	}
	
	func testSimpleQuery() {
		let client = Client(Client.Config(user: "postgres", database: "truckee"))
		
		let expectation = self.expectation(description: "query")
		
		client.connect(completion: { _ in
			let connection = client.connection!
			
			connection.readyForQuery.once() { _ in
				connection.simpleQuery("SELECT * FROM posts;")
				
				var gotDescription = false
				connection.rowDescriptionReceived.once() { fields in
					gotDescription = true
					
					XCTAssertEqual(fields.count, 4)
				}
				
				var rowCount = 0
				connection.rowReceived.observe() { fields in
					rowCount += 1
					
					XCTAssertEqual(fields.count, 4)
					
					if rowCount == 2 {
						XCTAssertTrue(gotDescription)
						expectation.fulfill()
					} else if rowCount > 2 {
						XCTFail()
					}
				}
			}
		})
		
		waitForExpectations(timeout: 5)
	}


    static var allTests: [(String, (ClientTests) -> () -> Void)] = [
        ("testExample", testInvalidURL),
        ("testConnect", testConnect),
        ("testClientQuery", testClientQuery),
        ("testSimpleQuery", testSimpleQuery),
    ]
}
