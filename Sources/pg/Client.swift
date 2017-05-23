import Foundation


public final class Client: NotificationObservable {
	public enum Error: Swift.Error {
		case invalidConnectionURL
		case connectionFailure
		case statementWithNameAlreadyExists
	}
	
	
	public struct Config {
		public static let defaultPort = 5432
		
		
		public var user: String
		public var password: String?
		public var database: String?
		public var port: Int
		public var host: String
		public var useSSL: Bool
		
		public init(host: String = "localhost", user: String, password: String? = nil, database: String?, port: Int = Config.defaultPort, useSSL: Bool = false) {
			self.host = host
			self.user = user
			self.password = password
			self.database = database?.isEmpty ?? true ? nil : database
			self.port = port
			self.useSSL = useSSL
		}
		
		public init(url: URL) throws {
			guard url.scheme == "postgres" || url.scheme?.isEmpty ?? true else { throw Error.invalidConnectionURL }
			// TODO: Default individual config properties to ENV variables
			
			guard
				let host = url.host, !host.isEmpty,
				let user = url.user, !user.isEmpty,
				!url.path.isEmpty
				else { throw Error.invalidConnectionURL }
			
			self.init(
				host: host,
				user: user,
				password: url.password,
				database: url.path,
				port: url.port ?? Config.defaultPort
			)
		}
	}
	
	
	private let queue = DispatchQueue(label: "PG.Client")
	
	public let config: Config
	
	public var typeParser = TypeParser.default
	
	public var notificationObservers: [Observer] = []
	public private(set) var connection: Connection?
	
	public init(_ config: Config) {
		self.config = config
	}
	
	
	// MARK: - Notifications
	
	public let connected = EventEmitter<Void>(name: "PG.Client.connected")
	public let loginSuccess = EventEmitter<Void>(name: "PG.Client.loginSuccess")
	
	
	// MARK: -
	
	public var isConnected: Bool {
		return connection?.isConnected ?? false
	}
	
	public var isAuthenticated: Bool {
		return connection?.isAuthenticated ?? false
	}
	
	
	// MARK: -
	
	public func connect(completion: ((Error?) -> Void)?) {
		var completion = completion // we only want to call this once, so remove it when we do
		var input: InputStream?
		var output: OutputStream?
		
		Stream.getStreamsToHost(withName: config.host, port: config.port, inputStream: &input, outputStream: &output)
		
		if let input = input, let output = output {
			if config.useSSL {
				input.setProperty(kCFStreamSocketSecurityLevelTLSv1, forKey: .socketSecurityLevelKey)
				output.setProperty(kCFStreamSocketSecurityLevelTLSv1, forKey: .socketSecurityLevelKey)
			}
			
			let connection = Connection(input: input, output: output)
			self.connection = connection
			
			connection.loginSuccess.observe(on: self.queue) {
				completion?(nil)
				completion = nil
				
				self.loginSuccess.emit()
			}
			
			connection.connected.observe {
				self.connected.emit()
			}
			
			connection.readyForQuery.observe(on: self.queue) { _ in
				self.executeQuery()
			}
			
			for stream in [input, output] {
				stream.schedule(in: .current, forMode: .defaultRunLoopMode)
				stream.open()
			}
			
			connection.sendStartup(user: config.user, database: config.database)
		} else {
			completion?(Error.connectionFailure)
			completion = nil
		}
	}
	
	
	// MARK: - Query
	
	private var preparedStatements: [Query.Statement] = []
	
	private var queryQueue: [(Connection) -> Void] = []
	
	private func enqueuQueryOperation(_ queryOperation: @escaping (Connection) -> Void) {
		queue.async {
			self.queryQueue.append(queryOperation)
			self.executeQuery()
		}
	}
	
	private func executeQuery() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		guard let connection = self.connection, connection.transactionStatus == .idle else { return }
		guard queryQueue.count > 0 else { return }
		let query = queryQueue.removeFirst()
		
		
		query(connection)
	}
	
	
	public func exec(_ query: Query, callback: ((Result<QueryResult>) -> Void)?) {
		if let callback = callback {
			query.completed.once(callback)
		}
		
		enqueuQueryOperation { connection in
			var observers: [AnyEventEmitterObserver] = []
			
			
			var fields: [Field] = []
			observers.append(connection.rowDescriptionReceived.once() { fields = $0 })
			
			var rows: [[DataSlice?]] = []
			observers.append(connection.rowReceived.observe() { rowFields in
				rows.append(rowFields)
			})
			
			
			observers.append(connection.error.once({ error in
				query.completed.emit(Result.failure(error))
				
				for observer in observers {
					observer.remove()
				}
			}))
			
			observers.append(connection.commandComplete.once() { commandResponse in
				do {
					let result = try QueryResult(commandResponse: commandResponse, fields: fields, rows: rows, typeParser: self.typeParser)
					query.completed.emit(Result.success(result))
				} catch {
					query.completed.emit(Result.failure(error))
				}
				
				for observer in observers {
					observer.remove()
				}
			})
			
			
			do {
				try self.executeExtendedQuery(query, on: connection)
				//		self.executeSimpleQuery(query, on: connection)
			} catch {
				query.completed.emit(Result.failure(error))
				
				for observer in observers {
					observer.remove()
				}
			}
		}
	}
	
	private func executeSimpleQuery(_ query: Query, on connection: Connection) {
		connection.simpleQuery(query.string)
	}
	
	private func executeExtendedQuery(_ query: Query, on connection: Connection) throws {
		if let statement = query.statement {
			if !self.preparedStatements.contains(statement) {
				guard !self.preparedStatements.contains(where: { $0.name == statement.name }) else {
					throw Error.statementWithNameAlreadyExists
				}
				self.preparedStatements.append(statement)
				
				connection.parse(
					name: statement.name,
					query: query.string,
					types: statement.bindingTypes.map({ $0?.pgTypes.first ?? 0 })
				)
			}
		} else {
			// if the statement has already been prepared we can skip this step
			let types = query.currentBindingTypes.map({ $0?.pgTypes.first ?? 0 })
			connection.parse(query: query.string, types: types)
		}
		
		connection.bind(statementName: query.statement?.name ?? "", parameters: query.bindings)
		
		connection.describePortal()
		
		connection.execute()
		
		connection.sync()
	}
	
	
	public func prepare(_ query: Query, callback: ((Result<Query.Statement>) -> Void)?) {
		enqueuQueryOperation { connection in
			let statement: Query.Statement
			if let existing = query.statement {
				statement = existing
			} else {
				statement = query.createStatement()
			}
			
			if self.preparedStatements.contains(statement) {
				// already prepared on this connection
				callback?(Result.success(statement))
				return
			}
			
			guard !self.preparedStatements.contains(where: { $0.name == statement.name }) else {
				callback?(Result.failure(Error.statementWithNameAlreadyExists))
				return
			}
			self.preparedStatements.append(statement)
			
			
			var parseComplete: EventEmitter<Void>.Observer?
			var errorResponse: EventEmitter<ServerError>.Observer? = nil
			
			parseComplete = connection.parseComplete.once() {
				callback?(Result.success(statement))
				
				errorResponse?.remove()
			}
			
			errorResponse = connection.errorResponse.once({ error in
				callback?(Result.failure(error))
				
				parseComplete?.remove()
			})
			
			
			connection.parse(
				name: statement.name,
				query: query.string,
				types: statement.bindingTypes.map({ $0?.pgTypes.first ?? 0 })
			)
			
			connection.sync()
		}
	}
}
