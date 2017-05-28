import XCTest
@testable import PG

class ClientTests: XCTestCase {
	private let host = ProcessInfo.processInfo.environment["POSTGRES_HOST"] ?? "localhost"
	private let user = ProcessInfo.processInfo.environment["POSTGRES_USER"] ?? "postgres"
	private let database = ProcessInfo.processInfo.environment["POSTGRES_DB"] ?? "pg_swift_tests"
	
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
		let client = Client(Client.Config(host: host, user: user, database: database))
		
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
		let client = Client(Client.Config(host: host, user: user, database: database))
		
		let expectation = self.expectation(description: "query")
		
		client.connect() { _ in
			client.exec("SELECT * FROM example;") { result in
				switch result {
				case .success(let result):
					XCTAssertEqual(result.fields.count, 19)
					XCTAssertEqual(result.rows.count, 2)
					XCTAssertEqual(result.rowCount, 2)
				case .failure(let error):
					XCTFail("error: \(error)")
				}
				
				expectation.fulfill()
			}
		}
		
		waitForExpectations(timeout: 5)
	}
	
	func testQueryBindings() {
		let client = Client(Client.Config(host: host, user: user, database: database))
		
		let expectation = self.expectation(description: "query")
		
		client.connect() { _ in
			let id = UUID(uuidString: "A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11")
			let query = Query("SELECT * FROM example WHERE e_uuid = $1;", id)
			client.exec(query) { result in
				switch result {
				case .success(let result):
					XCTAssertEqual(result.fields.count, 19)
					XCTAssertEqual(result.rows.count, 1)
					XCTAssertEqual(result.rowCount, 1)
					
					XCTAssertEqual(result.rows[0]["e_uuid"] as? UUID, id)
					
					XCTAssertEqual(result.rows[0]["e_text"] as? String, "Hello World")
					XCTAssertEqual(result.rows[0]["e_varchar_100"] as? String, "Hello World")
					XCTAssertEqual(result.rows[0]["e_varchar"] as? String, "Hello World")
					XCTAssertEqual(result.rows[0]["e_char"] as? String, "H")
					
					XCTAssertEqual(result.rows[0]["e_int2"] as? Int16, 100)
					XCTAssertEqual(result.rows[0]["e_int4"] as? Int32, 65635)
					XCTAssertEqual(result.rows[0]["e_int8"] as? Int64, 4294967395)
					XCTAssertEqual(result.rows[0].value(for: "e_int8"), 4294967395)
					XCTAssertEqual(result.rows[0].value(for: "e_int8") as Int?, 4294967395)
					XCTAssertEqual(result.rows[0]["e_oid"] as? OID, 65635)
					
					XCTAssertEqual(result.rows[0]["e_timestamp"] as? Date, Date(timeIntervalSince1970: 1495465975.3329999))
					XCTAssertEqual(result.rows[0]["e_date"] as? Date, Date(timeIntervalSince1970: 1495411200.0))
				case .failure(let error):
					XCTFail("error: \(error)")
				}
				
				expectation.fulfill()
			}
		}
		
		waitForExpectations(timeout: 5)
	}
	
	func testBindingUpdate() {
		let client = Client(Client.Config(host: host, user: user, database: database))
		
		let expectation = self.expectation(description: "query")
		
		client.connect() { _ in
			let idA = UUID(uuidString: "A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11")
			let idB = UUID(uuidString: "b7ab0ffc-9367-4fe6-a737-2fa4e5de58d3")
			
			var query = Query("SELECT * FROM example WHERE e_uuid = $1;", idA)
			client.exec(query) { result in
				switch result {
				case .success(let result):
					XCTAssertEqual(result.fields.count, 19)
					XCTAssertEqual(result.rows.count, 1)
					XCTAssertEqual(result.rowCount, 1)
					
					XCTAssertEqual(result.rows[0]["e_uuid"] as? UUID, idA)
					
					
					try! query.update(bindings: [idB])
					client.exec(query) { result in
						switch result {
						case .success(let result):
							XCTAssertEqual(result.fields.count, 19)
							XCTAssertEqual(result.rows.count, 1)
							XCTAssertEqual(result.rowCount, 1)
							
							XCTAssertEqual(result.rows[0]["e_uuid"] as? UUID, idB)
						case .failure(let error):
							XCTFail("error: \(error)")
						}
						
						expectation.fulfill()
					}
				case .failure(let error):
					XCTFail("error: \(error)")
				}
			}
		}
		
		waitForExpectations(timeout: 5)
	}
	
	func testPreparedStatement() {
		let client = Client(Client.Config(host: host, user: user, database: database))
		
		let expectation = self.expectation(description: "query")
		
		client.connect() { _ in
			let idA = UUID(uuidString: "A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11")
			let idB = UUID(uuidString: "b7ab0ffc-9367-4fe6-a737-2fa4e5de58d3")
			
			var query = Query("SELECT * FROM example WHERE e_uuid = $1;", idA)
			let statement = query.createStatement()
			client.prepare(statement) { error in
				XCTAssertNil(error)
				
				client.exec(query) { result in
					switch result {
					case .success(let result):
						XCTAssertEqual(result.fields.count, 19)
						XCTAssertEqual(result.rows.count, 1)
						XCTAssertEqual(result.rowCount, 1)
						
						XCTAssertEqual(result.rows[0]["e_uuid"] as? UUID, idA)
						
						
						try! query.update(bindings: [idB])
						client.exec(query) { result in
							switch result {
							case .success(let result):
								XCTAssertEqual(result.fields.count, 19)
								XCTAssertEqual(result.rows.count, 1)
								XCTAssertEqual(result.rowCount, 1)
								
								XCTAssertEqual(result.rows[0]["e_uuid"] as? UUID, idB)
							case .failure(let error):
								XCTFail("error: \(error)")
							}
							
							expectation.fulfill()
						}
					case .failure(let error):
						XCTFail("error: \(error)")
					}
				}
			}
		}
		
		waitForExpectations(timeout: 5)
	}
	

    static var allTests: [(String, (ClientTests) -> () -> Void)] = [
        ("testExample", testInvalidURL),
        ("testConnect", testConnect),
        ("testSimpleQuery", testSimpleQuery),
        ("testQueryBindings", testQueryBindings),
        ("testBindingUpdate", testBindingUpdate),
        ("testPreparedStatement", testPreparedStatement),
    ]
}
