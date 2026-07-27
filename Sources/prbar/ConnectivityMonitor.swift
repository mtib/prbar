import Foundation
import Network
import Observation

/// Tracks whether the machine has a usable route, so polls are skipped while offline and
/// fired immediately when the link comes back.
@MainActor
@Observable
final class ConnectivityMonitor {
    private(set) var isOnline = true

    var onReconnect: (@MainActor () -> Void)?

    private let monitor = NWPathMonitor()

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self, self.isOnline != online else { return }
                self.isOnline = online
                if online { self.onReconnect?() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "dev.mtib.prbar.connectivity"))
    }
}
