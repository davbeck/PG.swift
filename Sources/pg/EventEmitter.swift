import Foundation
import Dispatch


/// Type erasure for EventEmitter<Payload>.Observer
///
/// You can use this to, for instance, keep an array of observers that should all be cleared at some point.
public protocol AnyEventEmitterObserver {
	func remove()
}


public protocol NotificationPayload {
	var notificationUserInfo: [AnyHashable:Any] { get }
}


/// An emitter of a single event.
///
/// An event emitter excecutes any observing callbacks when it is emitted.
///
/// Payload is the type of data that is sent with events.
public class EventEmitter<Payload> {
	/// An event observer
	public class Observer: Equatable, AnyEventEmitterObserver {
		fileprivate let queue: DispatchQueue?
		fileprivate let callback: (Payload) -> Void
		fileprivate weak var emitter: EventEmitter<Payload>?
		
		fileprivate init(queue: DispatchQueue?, callback: @escaping (Payload) -> Void) {
			self.queue = queue
			self.callback = callback
		}
		
		/// Remove the observer from the event so that it stops receiving events and cleans up it's memory
		public func remove() {
			emitter?.remove(self)
		}
		
		public static func == (_ lhs: Observer, _ rhs: Observer) -> Bool {
			return lhs === rhs
		}
	}
	
	private let queue: DispatchQueue
	private var observers: [Observer] = []
	
	/// The name of a notification that will be posted when the event is emitted
	///
	/// When set, events post a notification to the default notification center when they are emitted. If Payload conforms to `NotificationPayload`, it's `notificationUserInfo` is used for the `userInfo` dictionary.
	public let notificationName: Notification.Name?
	
	
	/// Create a new event.
	///
	/// An event can be created anywhere, but is most commonly a let instance variable that represents an objects events.
	///
	/// - Parameter name: Optionally the name of the notification that will be posted when the event emits.
	public init(name: String? = nil) {
		queue = DispatchQueue(label: "EventEmitter<\(Payload.self)>.\(name ?? "")")
		if let name = name {
			notificationName = Notification.Name(rawValue: name)
		} else {
			notificationName = nil
		}
	}
	
	
	/// Emit an event and notify observers
	///
	/// If `notificationName` is not nil, a notification will also be posted. If Payload is a `NotificationPayload`, it's `notificationUserInfo` will be used for the 'userInfo' dictionary. The object is always the event emitter.
	///
	/// - Parameter payload: The payload to send to the observers.
	public func emit(_ payload: Payload) {
		queue.sync {
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
				var userInfo: [AnyHashable:Any] = [:]
				if let payload = payload as? NotificationPayload {
					userInfo = payload.notificationUserInfo
				}
				
				NotificationCenter.default.post(name: name, object: self, userInfo: userInfo)
			}
		}
	}
	
	
	/// Create a new observer with a callback
	///
	/// - Parameters:
	///   - queue: The queue the callback should be called on. Defaults to the event's queue.
	///   - callback: The block to be called when the event is emitted.
	/// - Returns: A new observer that can be used to remove the observer.
	@discardableResult
	public func observe(on queue: DispatchQueue? = nil, _ callback: @escaping (Payload) -> Void) -> Observer {
		let observer = Observer(queue: queue, callback: callback)
		observer.emitter = self
		
		self.queue.async {
			self.observers.append(observer)
		}
		
		return observer
	}
	
	/// Create a new observer that will only be called once
	///
	/// - Parameters:
	///   - queue: The queue the callback should be called on. Defaults to the event's queue.
	///   - callback: The block to be called when the event is emitted.
	/// - Returns: A new observer that can be used to remove the observer.
	@discardableResult
	public func once(on queue: DispatchQueue? = nil, _ callback: @escaping (Payload) -> Void) -> Observer {
		var observer: Observer?
		
		observer = self.observe(on: queue) { (payload) in
			observer?.remove()
			
			callback(payload)
		}
		
		return observer!
	}
	
	/// Remove an observer
	///
	/// Equivalent to `Observer.remove`.
	///
	/// - Parameter observer: The observer to remove.
	public func remove(_ observer: Observer) {
		queue.async {
			self.observers = self.observers.filter({ $0 !== observer })
		}
	}
}

extension EventEmitter where Payload == Void {
	public func emit() {
		self.emit(Void())
	}
}
