import Foundation


public final class Client: NotificationObservable {
	public enum Error: Swift.Error {
		case invalidConnectionURL
		case connectionFailure
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
	
	
	public let config: Config
	
	public var notificationObservers: [Observer] = []
	var connection: Connection?
	
	public init(_ config: Config) {
		self.config = config
	}
	
	
	// MARK: - Notifications
	
	public static let connected = NotificationDescriptor<VoidPayload>("PG.Connection.connected")
	public static let loginSuccess = NotificationDescriptor<VoidPayload>("PG.Connection.loginSuccess")
	
	
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
			
			self.connection = Connection(input: input, output: output)
			
			self.observe(Connection.loginSuccess, object: connection, using: { [weak self] _ in
				completion?(nil)
				completion = nil
				
				Client.loginSuccess.post(sender: self)
			})
			self.observe(Connection.connected, object: connection, using: { [weak self] _ in
				Client.connected.post(sender: self)
			})
			
			for stream in [input, output] {
				stream.schedule(in: .current, forMode: .defaultRunLoopMode)
				stream.open()
			}
			
			connection?.sendStartup(user: config.user, database: config.database)
		} else {
			completion?(Error.connectionFailure)
			completion = nil
		}
	}
}
