public protocol Socket {
	func connect()
	
	/// If the connection has been established
	var isConnected: Bool { get }
	
	
	// MARK: - Events
	
	/// Emitted when the connection is established with the server
	var connected: EventEmitter<Void> { get }
	
	/// Write some data to the socket and call completion when it has been sent
	///
	/// Writes *must* be performed sequentially and their completion callbacks called sequentially. A connection may call this method multiple times in a row and wait for the last completion block before moving on.
	func write(data: Data, completion: (() -> Void)?)
	
	func read(length: Int, completion: ((Data) -> Void)?)
}
