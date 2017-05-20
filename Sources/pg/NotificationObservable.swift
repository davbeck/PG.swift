import Foundation


public protocol NotificationPayload {
	init(userInfo: [AnyHashable:Any])
	var userInfo: [AnyHashable:Any] { get }
}

public struct VoidPayload: NotificationPayload {
	public init() {
		
	}
	
	public init(userInfo: [AnyHashable:Any]) {
		self.init()
	}
	
	public var userInfo: [AnyHashable:Any] {
		return [:]
	}
}


public struct NotificationDescriptor<Payload: NotificationPayload> {
	public let name: Notification.Name
	
	public init(_ name: Notification.Name) {
		self.name = name
	}
	
	public init(_ name: String) {
		self.init(Notification.Name(name))
	}
	
	
	public func post(sender: Any?, _ payload: Payload) {
		NotificationCenter.default.post(name: name, object: sender, userInfo: payload.userInfo)
	}
	
	public func observe(object obj: Any?, queue: OperationQueue? = nil, using block: @escaping (Payload) -> Swift.Void) -> NSObjectProtocol {
		return NotificationCenter.default.addObserver(forName: self.name, object: obj, queue: queue) { (notification) in
			block(Payload(userInfo: notification.userInfo ?? [:]))
		}
	}
	
	@discardableResult
	public func observeOnce(object obj: Any?, queue: OperationQueue? = nil, using block: @escaping (Payload) -> Swift.Void) -> NSObjectProtocol {
		var observer: NSObjectProtocol?
		observer = NotificationCenter.default.addObserver(forName: self.name, object: obj, queue: queue) { (notification) in
			NotificationCenter.default.removeObserver(observer)
			block(Payload(userInfo: notification.userInfo ?? [:]))
		}
		return observer!
	}
}

extension NotificationDescriptor where Payload == VoidPayload {
	public func post(sender: Any?) {
		NotificationCenter.default.post(name: name, object: sender, userInfo: [:])
	}
}


public class Observer {
	public let rawValue: NSObjectProtocol
	
	public init(rawValue: NSObjectProtocol) {
		self.rawValue = rawValue
	}
	
	deinit {
		NotificationCenter.default.removeObserver(rawValue)
	}
}


public protocol NotificationObservable: AnyObject {
	var notificationObservers: [Observer] { get set }
}

extension NotificationObservable {
	public func observe<Payload>(_ descriptor: NotificationDescriptor<Payload>, object obj: Any?, queue: OperationQueue? = nil, using block: @escaping (Payload) -> Swift.Void) {
		let observer = NotificationCenter.default.addObserver(forName: descriptor.name, object: obj, queue: queue) { (notification) in
			block(Payload(userInfo: notification.userInfo ?? [:]))
		}
		
		self.notificationObservers.append(Observer(rawValue: observer))
	}
}
