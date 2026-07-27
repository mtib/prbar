import AppKit
import Foundation
import Observation
import PRBarCore

@MainActor
@Observable
final class AppModel {
    static let pollInterval: Duration = .seconds(60)

    var selectedBucket: ReviewBucket = .direct
    private(set) var queue = ReviewQueue.empty
    private(set) var user: String?
    private(set) var lastRefresh: Date?
    private(set) var lastError: String?
    private(set) var isRefreshing = false

    let settings: AppSettings
    let connectivity = ConnectivityMonitor()

    private let notifier = Notifier()
    private let stateStore: NotifyStateStore
    private var notified: Set<String>?
    private var pollTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(settings: AppSettings = AppSettings(), stateStore: NotifyStateStore = .inApplicationSupport()) {
        self.settings = settings
        self.stateStore = stateStore
        self.notified = stateStore.load()
    }

    var isOnline: Bool { connectivity.isOnline }

    func count(_ bucket: ReviewBucket) -> Int { queue[bucket].count }

    func start() {
        guard pollTask == nil else { return }
        connectivity.onReconnect = { [weak self] in self?.refresh() }
        connectivity.start()

        Task { await notifier.requestAuthorization() }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                if self?.connectivity.isOnline == true {
                    await self?.performRefresh()
                }
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    /// Fire-and-forget refresh for buttons and reconnects; coalesces with an in-flight poll.
    func refresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            await self?.performRefresh()
            self?.refreshTask = nil
        }
    }

    private func performRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let source = try settings.resolveSource()
            let snapshot = try await source.fetchQueue()
            user = snapshot.user
            queue = snapshot.queue
            lastRefresh = .now
            lastError = nil
            await announce(snapshot.queue)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func announce(_ queue: ReviewQueue) async {
        let plan = NotificationPlanner.plan(queue: queue, notified: notified)
        let directIDs = Set(queue.direct.map(\.id))
        for pullRequest in plan.toNotify {
            await notifier.post(pullRequest, isDirect: directIDs.contains(pullRequest.id))
        }
        notified = plan.notified
        try? stateStore.save(plan.notified)
    }

    func open(_ pullRequest: PullRequest) {
        NSWorkspace.shared.open(pullRequest.url)
    }
}
