import AppKit
import Foundation
import Observation
import PRBarCore

@MainActor
@Observable
final class AppModel {
    /// The loop wakes on this cadence regardless of the poll interval, so shortening the
    /// interval takes effect within a tick instead of after the long sleep already in flight,
    /// and a mute deadline lands on time even when polling hourly.
    static let tick: Duration = .seconds(5)
    /// The histogram's longest span, so one fetch feeds both the 7- and 30-day views.
    static let activityWindow = 30
    /// The history changes slowly and costs up to ~5 GraphQL pages, so it refreshes on its own,
    /// slower cadence; the refresh button and reconnects still force it.
    static let activityInterval: TimeInterval = 300

    var selectedBucket: ReviewBucket = .direct
    private(set) var queue = ReviewQueue.empty
    private(set) var reviewActivity = ReviewActivity.empty
    private(set) var user: String?
    private(set) var lastRefresh: Date?
    private(set) var lastError: String?
    private(set) var isRefreshing = false
    private(set) var hasLoadedQueue = false
    private(set) var hasLoadedActivity = false

    let settings: AppSettings
    let connectivity = ConnectivityMonitor()

    private let notifier = Notifier()
    private let stateStore: NotifyStateStore
    private var notified: Set<String>?
    private var pollTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var cachedUser: (auth: String, login: String)?
    private var lastActivityFetch: Date?

    init(settings: AppSettings = AppSettings(), stateStore: NotifyStateStore = .inApplicationSupport()) {
        self.settings = settings
        self.stateStore = stateStore
        self.notified = stateStore.load()
    }

    var isOnline: Bool { connectivity.isOnline }

    func count(_ bucket: ReviewBucket) -> Int { queue[bucket].count }

    /// Distinct PRs reviewed today, in the user's own calendar.
    var reviewedToday: Int { reviewActivity.distinctPullRequests(on: .now) }

    func dailyCounts(days: Int) -> [DayCount] { reviewActivity.dailyCounts(days: days) }

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
                await self?.waitForNextPoll()
            }
        }
    }

    /// Sleeps until the chosen interval has elapsed, re-reading it as it goes.
    private func waitForNextPoll() async {
        let start = Date.now
        while !Task.isCancelled {
            settings.expireMuteIfDue()
            let remaining = settings.pollInterval.seconds - Date.now.timeIntervalSince(start)
            guard remaining > 0 else { return }
            try? await Task.sleep(for: min(Self.tick, .seconds(remaining)))
        }
    }

    /// Fire-and-forget refresh for buttons and reconnects; coalesces with an in-flight poll.
    func refresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            await self?.performRefresh(force: true)
            self?.refreshTask = nil
        }
    }

    private func performRefresh(force: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        settings.expireMuteIfDue()

        do {
            let source = try settings.resolveSource()
            let known = cachedUser?.auth == source.describedAuth ? cachedUser?.login : nil
            let snapshot = try await source.fetchQueue(knownUser: known)
            cachedUser = (source.describedAuth, snapshot.user)
            user = snapshot.user
            queue = snapshot.queue
            hasLoadedQueue = true
            lastRefresh = .now
            lastError = nil
            await announce(snapshot.queue)
            if force || activityIsDue {
                await refreshActivity(from: source, user: snapshot.user)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func announce(_ queue: ReviewQueue) async {
        let plan = NotificationPlanner.plan(
            queue: queue,
            notified: notified,
            mode: settings.notificationMode
        )
        for pullRequest in plan.toNotify {
            await notifier.post(pullRequest)
        }
        notified = plan.notified
        try? stateStore.save(plan.notified)
    }

    private var activityIsDue: Bool {
        guard let lastActivityFetch else { return true }
        return Date.now.timeIntervalSince(lastActivityFetch) >= Self.activityInterval
    }

    /// Review history is cosmetic: a failure here must not blank the queue or raise an error
    /// banner, so it is fetched after the queue and swallowed.
    private func refreshActivity(from source: any PullRequestSource, user: String) async {
        let start = Calendar.current.startOfDay(for: .now)
        guard let since = Calendar.current.date(
            byAdding: .day, value: -(Self.activityWindow - 1), to: start
        ) else { return }
        if let activity = try? await source.fetchReviewActivity(user: user, since: since) {
            reviewActivity = activity
            hasLoadedActivity = true
            lastActivityFetch = .now
        }
    }

    func open(_ pullRequest: PullRequest) {
        NSWorkspace.shared.open(pullRequest.url)
    }
}
