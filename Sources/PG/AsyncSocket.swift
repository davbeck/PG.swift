import Foundation
import Dispatch
import NIO


extension MultiThreadedEventLoopGroup {
	public static let pgShared = MultiThreadedEventLoopGroup(numberOfThreads: 1)
}

public class NIOSocket: ConnectionSocket, ChannelInboundHandler {
	fileprivate let queue = DispatchQueue(label: "NIOSocket")
	let group: MultiThreadedEventLoopGroup
	var bootstrap: ClientBootstrap?
	var channel: Channel?
	
	init(group: MultiThreadedEventLoopGroup = .pgShared) {
		self.group = group
		
		bootstrap = ClientBootstrap(group: group)
			// Enable SO_REUSEADDR.
			.channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
			.channelInitializer({ channel in
				channel.pipeline.add(handler: self)
			})
	}
	
	
	// MARK - ChannelInboundHandler
	
	public typealias InboundIn = ByteBuffer
	public typealias OutboundOut = ByteBuffer
	
	public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
		let buffer = self.unwrapInboundIn(data)
		let data = Data(buffer.getBytes(at: 0, length: buffer.readableBytes) ?? [])
		queue.async {
			self.inputBuffer.append(data)
			self.performRead()
		}
	}
	
	public func errorCaught(ctx: ChannelHandlerContext, error: Error) {
		ctx.close(promise: nil)
		
		closed.emit()
	}
	
	public func channelActive(ctx: ChannelHandlerContext) {
		connected.emit()
	}
	
	
	// MARK: - Events
	
	public let connected = EventEmitter<Void>()
	
	public let closed = EventEmitter<Void>()
	
	
	public func connect(host: String, port: Int32) throws {
		bootstrap?.connect(host: host, port: Int(port))
			.whenSuccess({ (channel) in
				self.channel = channel
				
				channel.closeFuture.whenComplete({
					self.closed.emit()
					self.channel = nil
				})
			})
	}
	
	public func close() {
		_ = channel?.close(mode: .all)
	}
	
	public var isConnected: Bool {
		return channel?.isActive ?? false
	}
	
	public func write(data: Data, completion: ((Error?) -> Void)?) {
		guard let channel = self.channel else { return }
		
		var buffer = channel.allocator.buffer(capacity: data.count)
		buffer.write(bytes: data)
		
		let result = channel.writeAndFlush(buffer)
		result.whenSuccess({
			completion?(nil)
		})
		result.whenFailure({ (error) in
			completion?(error)
		})
	}
	
	
	// MARK: - Reading
	
	private var inputBuffer = Data()
	
	struct ReadRequest {
		let length: Int
		let completion: ((Result<Data>) -> Void)?
	}
	
	private var readQueue: [ReadRequest] = []
	
	public func read(length: Int, completion: ((Result<Data>) -> Void)?) {
		queue.async {
			let request = ReadRequest(length: length, completion: completion)
			self.readQueue.append(request)
			
			self.performRead()
		}
	}
	
	fileprivate func performRead() {
		if #available(OSX 10.12, *) {
			dispatchPrecondition(condition: .onQueue(self.queue))
		}
		
		// if we have any extra data left over from our last read, use it
		var inputBuffer = self.inputBuffer
		var offset = inputBuffer.startIndex
		
		while readQueue.count > 0 {
			let current = readQueue[0]
			guard inputBuffer.count >= current.length else { break }
			readQueue.removeFirst()
			
			let range = offset..<(offset + current.length)
			current.completion?(.success(Data(inputBuffer[range])))
			offset = range.endIndex
		}
		
		// save the left overs for the next read
		self.inputBuffer.removeFirst(offset - inputBuffer.startIndex)
	}
}
