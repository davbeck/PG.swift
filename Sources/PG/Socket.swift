import Foundation
import AsyncKit


/// An abstract socket interface.
public protocol ConnectionSocket {
	/// Connect to the socket
	func connect(host: String, port: Int32) throws
	
	func close()
	
	/// If the connection has been established
	var isConnected: Bool { get }
	
	
	// MARK: - Events
	
	/// Emitted when the connection is established with the server
	var connected: EventEmitter<Void> { get }
	
	/// Emitted when the connection is closed
	var closed: EventEmitter<Void> { get }
	
	/// Write some data to the socket and call completion when it has been sent
	///
	/// Writes *must* be performed sequentially and their completion callbacks called sequentially. A connection may call this method multiple times in a row and wait for the last completion block before moving on.
	func write(data: Data, completion: ((Error?) -> Void)?)
	
	/// Read some data from the socket and call completion when it has been sent
	///
	/// If there is no data available from the socket when this is called, it should be queued up until data does arrive.
	///
	/// - Parameters:
	///   - length: The number of bytes to read.
	///   - completion: Called when the data has been read.
	func read(length: Int, completion: ((Result<Data>) -> Void)?)
}
