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
	
	func testSimpleQuery() {
		let client = Client(Client.Config(user: "postgres", database: "truckee"))
		
		let expectation = self.expectation(description: "query")
		
		client.connect() { _ in
			client.exec("SELECT * FROM posts;") { result in
				switch result {
				case .success(let result):
					XCTAssertEqual(result.fields.count, 4)
					XCTAssertEqual(result.rows.count, 2)
					XCTAssertEqual(result.rowCount, 2)
					
					let array = Array(result.rows.map({ Dictionary($0) }))
					print("array: \(array)")
				case .failure(let error):
					XCTFail("error: \(error)")
				}
				
				expectation.fulfill()
			}
		}
		
		waitForExpectations(timeout: 5)
	}
	
	func testQueryBindings() {
		let client = Client(Client.Config(user: "postgres", database: "truckee"))
		
		let expectation = self.expectation(description: "query")
		
		client.connect() { _ in
			let id = UUID(uuidString: "A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11")
			let query = Query("SELECT * FROM posts WHERE id = $1;", id)
			client.exec(query) { result in
				switch result {
				case .success(let result):
					XCTAssertEqual(result.fields.count, 4)
					XCTAssertEqual(result.rows.count, 1)
					XCTAssertEqual(result.rowCount, 1)
					
					XCTAssertEqual(result.rows[0]["id"] as? UUID, id)
					
					let array = Array(result.rows.map({ Dictionary($0) }))
					print("array: \(array)")
				case .failure(let error):
					XCTFail("error: \(error)")
				}
				
				expectation.fulfill()
			}
		}
		
		waitForExpectations(timeout: 5)
	}
	

    static var allTests: [(String, (ClientTests) -> () -> Void)] = [
        ("testExample", testInvalidURL),
        ("testConnect", testConnect),
        ("testSimpleQuery", testSimpleQuery),
        ("testQueryBindings", testQueryBindings),
    ]
}
