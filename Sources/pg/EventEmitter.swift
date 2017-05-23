import Foundation


public protocol AnyEventEmitterObserver {
	func remove()
}


public class EventEmitter<Payload> {
	public class Observer: Equatable, AnyEventEmitterObserver {
		fileprivate let queue: DispatchQueue?
		fileprivate let callback: (Payload) -> Void
		fileprivate weak var emitter: EventEmitter<Payload>?
		
		fileprivate init(queue: DispatchQueue?, callback: @escaping (Payload) -> Void) {
			self.queue = queue
			self.callback = callback
		}
		
		public func remove() {
			emitter?.remove(self)
		}
		
		public static func == (_ lhs: Observer, _ rhs: Observer) -> Bool {
			return lhs === rhs
		}
	}
	
	private let queue: DispatchQueue
	private var observers: [Observer] = []
	public let notificationName: Notification.Name?
	
	public init(name: String? = nil) {
		queue = DispatchQueue(label: "EventEmitter<\(Payload.self)>.\(name ?? "")")
		if let name = name {
			notificationName = Notification.Name(name)
		} else {
			notificationName = nil
		}
	}
	
	
	public func emit(_ payload: Payload) {
		queue.async {
			for observer in self.observers {
				if let queue = observer.queue {
					queue.async {
						observer.callback(payload)
					}
				} else {
					observer.callback(payload)
				}
				
			}
			
			if let name = self.notificationName {
				NotificationCenter.default.post(name: name, object: self, userInfo: nil)
			}
		}
	}
	
	@discardableResult
	public func observe(on queue: DispatchQueue? = nil, _ callback: @escaping (Payload) -> Void) -> Observer {
		let observer = Observer(queue: queue, callback: callback)
		observer.emitter = self
		
		self.queue.async {
			self.observers.append(observer)
		}
		
		return observer
	}
	
	@discardableResult
	public func once(on queue: DispatchQueue? = nil, _ callback: @escaping (Payload) -> Void) -> Observer {
		var observer: Observer?
		
		observer = self.observe(on: queue) { (payload) in
			observer?.remove()
			
			callback(payload)
		}
		
		return observer!
	}
	
	public func remove(_ observer: Observer) {
		queue.async {
			self.observers = self.observers.filter({ $0 !== observer })
		}
	}
}
