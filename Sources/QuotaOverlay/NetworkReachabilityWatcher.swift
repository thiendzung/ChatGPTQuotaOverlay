import Foundation
import Network

final class NetworkReachabilityWatcher {
    var onReachable: (() -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "built-by-ThienDzung.network-events")
    private var lastSatisfied = false

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            if satisfied && !self.lastSatisfied {
                self.onReachable?()
            }
            self.lastSatisfied = satisfied
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    deinit { stop() }
}
