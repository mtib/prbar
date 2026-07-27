import Foundation

public struct NotifyPlan: Sendable, Equatable {
    public let toNotify: [PullRequest]
    public let notified: Set<String>

    public init(toNotify: [PullRequest], notified: Set<String>) {
        self.toNotify = toNotify
        self.notified = notified
    }
}

/// Decides which PRs deserve a notification, given what has already been announced.
public enum NotificationPlanner {
    /// - Parameter notified: keys already announced, or `nil` on the very first poll ever.
    ///
    /// The first poll seeds the state silently — otherwise the whole standing queue would
    /// arrive as a wall of banners. Keys that have left the queue are pruned, so a PR that is
    /// re-requested after being dealt with notifies again, and a draft flipping to ready
    /// notifies for the first time (drafts are never recorded as notified).
    public static func plan(queue: ReviewQueue, notified: Set<String>?) -> NotifyPlan {
        let present = Set(queue.all.map(\.id))
        let candidates = queue.notifiable

        guard let notified else {
            return NotifyPlan(toNotify: [], notified: Set(candidates.map(\.id)))
        }

        let fresh = candidates.filter { !notified.contains($0.id) }
        return NotifyPlan(
            toNotify: fresh,
            notified: notified.intersection(present).union(candidates.map(\.id))
        )
    }
}
