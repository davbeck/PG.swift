import Foundation
import Dispatch
import AsyncKit


public final class Client {
	public enum Error: Swift.Error {
		case invalidConnectionURL
		case connectionFailure
		case statementWithNameAlreadyExists
	}
	
	
	/// Configuration for clients and their connection
	public struct Config {
		/// The default PostgreSQL port
		public static let defaultPort = 5432
		
		
		/// The username to use when connecting to a server
		///
		/// Every connection must provide a username, and it cannot be empty.
		public var user: String
		
		/// The password used to authenticate when connecting to a server
		///
		/// Some servers are configured to accept any connection without passwords, in which case this can be nil. If the server does require a password and this is nil, there will be an error on connection.
		public var password: String?
		
		/// The database to connect to
		///
		/// If this is nil, the server will pick a default database (usually one matching the username).
		public var database: String?
		
		/// The port to connect on, defaults to `Config.defaultPort`
		public var port: Int
		
		/// The host to connect to
		///
		/// This can be a domain name, an IPv4 or v6.
		public var host: String
		
		
		/// Create a new configuration
		///
		/// - Parameters:
		///   - host: The host to connect to, defaults to localhost.
		///   - user: The username to use when connecting.
		///   - password: The password to use when connecting.
		///   - database: The database to use when connecting.
		///   - port: The port to connect on, defaults to 5432.
		public init(host: String = "localhost", user: String, password: String? = nil, database: String?, port: Int = Config.defaultPort) {
			self.host = host
			self.user = user
			self.password = password
			self.database = database?.isEmpty ?? true ? nil : database
			self.port = port
		}
		
		
		/// Create a new configuration from a postgres url.
		///
		/// The url *must* have a postgres scheme or no scheme, and have at least a host and user.
		///
		/// example url: `postgresql://[user[:password]@][host][:port][/dbname]`
		///
		/// - Parameter url: A postgres url.
		/// - Throws: Error.invalidConnectionURL if the url is not a valid postgres url.
		public init(url: URL) throws {
			guard url.scheme == "postgres" || url.scheme?.isEmpty ?? true else { throw Error.invalidConnectionURL }
			
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
	
	
	/// A serial queue used for thread safety when accessing client properties
	private let queue = DispatchQueue(label: "PG.Client")
	
	/// The client configuration the client was created with.
	public let config: Config
	
	/// The type parse for fetched results
	///
	/// You can add types to the parser here, or replace it with your own. At the point that results are returned, the parser is copied and locked to those results, so this only effects future query results.
	public var typeParser = TypeParser.default
	
	/// The current connection, or nil if the client is not connected
	///
	/// While the client is connecting this will not be nil, but `isConnected` will be `false`.
	public private(set) var connection: Connection?
	
	
	/// Create a new client
	///
	/// You must call `connect` on the returned client.
	///
	/// - Parameter config: The configuration to use for the client.
	public init(_ config: Config) {
		self.config = config
	}
	
	deinit {
		self.disconnect()
	}
	
	
	// MARK: - Notifications
	
	/// Emitted when a connection has been established with the server
	public let connected = EventEmitter<Void>(name: "PG.Client.connected")
	
	/// Emitted when a connection has been established with the server
	public let disconnected = EventEmitter<Void>(name: "PG.Client.disconnected")
	
	/// Emitted when a connection has been established and authenticated
	public let loginSuccess = EventEmitter<Void>(name: "PG.Client.loginSuccess")
	
	
	// MARK: -
	
	/// Whether the current connection has been established
	public var isConnected: Bool {
		return connection?.isConnected ?? false
	}
	
	/// Whether the current connection has been authenticated or not
	public var isAuthenticated: Bool {
		return connection?.isAuthenticated ?? false
	}
	
	
	// MARK: -
	
	/// Connect to the server
	///
	/// A `StreamSocket` is created with the given host and port.
	///
	/// - Parameter completion: Called once a connection is established. Note that this does not mean that the client has authenticated. Use the `Client.loginSuccess` event to watch for that. This is equivalent to `Client.connected`.
	public func connect(completion: ((Swift.Error?) -> Void)?) {
		do {
			let socket = try AsyncSocket()
			
			self.connect(with: socket, completion: completion)
		} catch {
			completion?(error)
		}
	}
	
	public func disconnect() {
		self.connection?.socket.close()
	}
	
	/// Create a connection with the custom socket
	///
	/// Normally you call `connect(completion:) instead of this method, but if you want to use your own custom socket connection, you can use this method to connect instead.
	///
	/// - Parameters:
	///   - socket: The socket to connect on.
	///   - completion: Called when the connection has been established and authenticated. Equivalent to the loginSuccess event.
	public func connect(with socket: ConnectionSocket, completion: ((Swift.Error?) -> Void)?) {
		do {
			if !socket.isConnected {
				socket.connected.once { [weak self] in
					self?.startup(with: socket, completion: completion)
				}
				
				try socket.connect(host: config.host, port: Int32(config.port))
			} else {
				self.startup(with: socket, completion: completion)
			}
		} catch {
			completion?(error)
		}
	}
	
	private func startup(with socket: ConnectionSocket, completion: ((Swift.Error?) -> Void)?) {
		var completion = completion // we only want to call this once, so remove it when we do
		
		precondition(socket.isConnected)
		self.connected.emit()
		
		socket.closed.once(on: self.queue) { [weak self] in
			self?.connection = nil
			
			self?.disconnected.emit()
		}
		
		let connection = Connection(socket: socket)
		self.connection = connection
		
		
		connection.authenticationCleartextPassword.observe(on: self.queue) { [weak self] in
			connection.sendPassword(self?.config.password ?? "")
		}
		
		connection.authenticationMD5Password.observe { [weak self] salt in
			guard let `self` = self else { return }
			connection.sendMD5Authentication(username: self.config.user, password: self.config.password ?? "", salt: salt)
		}
		
		
		connection.loginSuccess.once(on: self.queue) { [weak self] in
			completion?(nil)
			completion = nil
			
			self?.loginSuccess.emit()
		}
		
		connection.error.once(on: self.queue) { (error) in
			completion?(error)
			completion = nil
		}
		
		connection.readyForQuery.observe(on: self.queue) { [weak self] _ in
			self?.executeQuery()
		}
		
		
		connection.sendStartup(user: config.user, database: config.database)
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
	
	
	
	/// Execute a query on the server
	///
	/// If the query needs to be prepared, it will be done so automatically. On success, a `QueryResult` is returned that contains the type of result (INSERT, SELECT, etc) and any rows returned.
	///
	/// If a query is alredy in progress, or the client is not connected, this will be enqued until the connection is ready to process queries again.
	///
	/// Setting `resultsMode` to `.binary` can improve performance, particularly for the timestamp types, however the binary encodings are undocumented and should be used with caution. If a text encoded value can't be parsed, it will gracefully fallback to a String, but in binary mode it will fallback to a `DataSlice` that may not be meaningful.
	///
	/// - Parameters:
	///   - query: The query to be execute.
	///   - resultsMode: The encoding mode to use for the result types.
	///   - callback: Called once the query has been executed and all data returned, or when an error occurs. Note that this is equivalent to the `query.completed` event.
	public func exec(_ query: Query, resultsMode: Field.Mode = .text, callback: ((Result<QueryResult>) -> Void)?) {
		if let callback = callback {
			query.completed.once(callback)
		}
		
		enqueuQueryOperation { connection in
			var observers: [AnyEventEmitterObserver] = []
			
			
			var fields: [Field] = []
			observers.append(connection.rowDescriptionReceived.once(on: self.queue) { fields = $0 })
			
			var rows: [[DataSlice?]] = []
			observers.append(connection.rowReceived.observe(on: self.queue) { rowFields in
				rows.append(rowFields)
			})
			
			
			observers.append(connection.error.once(on: self.queue) { error in
				query.completed.emit(Result.failure(error))
				
				for observer in observers {
					observer.remove()
				}
			})
			
			observers.append(connection.commandComplete.once(on: self.queue) { commandResponse in
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
				if query.needsExtendedExcecution {
					try self.executeExtendedQuery(query, resultsMode: resultsMode, on: connection)
				} else {
					self.executeSimpleQuery(query, on: connection)
				}
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
	
	private func executeExtendedQuery(_ query: Query, resultsMode: Field.Mode, on connection: Connection) throws {
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
		
		connection.bind(statementName: query.statement?.name ?? "", parameters: query.bindings, resultModes: [resultsMode])
		
		connection.describePortal()
		
		connection.execute()
		
		connection.sync()
	}
	
	
	
	/// Explicitly prepare a query for execution
	///
	/// If the statement has already been prepared on the current connection, this method returns without interacting with the server. Normally you would not call this method. Instead you would call `Query.preparedStatements` to indicate you wanted to reuse the query and then call `Client.exec`, which will implicitly prepare the query the first time it is called. You can use this method if you want to aggresively process the query on the server beforehand.
	///
	/// See `Query.createStatement` for more information on prepared statements.
	///
	/// - Parameters:
	///   - statement: The statement to prepare.
	///   - callback: Called when the query has been prepared, or an error occured.
	public func prepare(_ statement: Query.Statement, callback: ((Swift.Error?) -> Void)?) {
		enqueuQueryOperation { connection in
			if self.preparedStatements.contains(statement) {
				// already prepared on this connection
				callback?(nil)
				return
			}
			
			guard !self.preparedStatements.contains(where: { $0.name == statement.name }) else {
				callback?(Error.statementWithNameAlreadyExists)
				return
			}
			self.preparedStatements.append(statement)
			
			
			var parseComplete: EventEmitter<Void>.Observer?
			var errorResponse: EventEmitter<ServerError>.Observer? = nil
			
			parseComplete = connection.parseComplete.once(on: self.queue) {
				callback?(nil)
				
				errorResponse?.remove()
			}
			
			errorResponse = connection.errorResponse.once(on: self.queue) { error in
				callback?(error)
				
				parseComplete?.remove()
			}
			
			
			connection.parse(
				name: statement.name,
				query: statement.string,
				types: statement.bindingTypes.map({ $0?.pgTypes.first ?? 0 })
			)
			
			connection.sync()
		}
	}
}
