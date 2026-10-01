import Foundation

protocol QuotaProvider: AnyObject {
    var onChange: ((Quota) -> Void)? { get set }
    func start()
    func stop()
    func refreshNow()
    func refreshIfOlder(than age: TimeInterval)
    func refreshAfterActivity()
}
