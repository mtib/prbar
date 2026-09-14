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
    ///
    /// `mode` only ever narrows `toNotify`. A PR silenced by the mode is still recorded as
    /// notified, so un-muting announces what arrives *next* rather than replaying everything
    /// that landed while you were quiet — the same reason the first poll seeds silently.
    public static func plan(
        queue: ReviewQueue,
        notified: Set<String>?,
        mode: NotificationMode = .all
    ) -> NotifyPlan {
        let present = Set(queue.all.map(\.id))
        let candidates = queue.notifiable

        guard let notified else {
            return NotifyPlan(toNotify: [], notified: Set(candidates.map(\.id)))
        }

        let fresh = candidates.filter { !notified.contains($0.id) }
        let directIDs = Set(queue.direct.map(\.id))
        let audible: [PullRequest] = switch mode {
        case .off: []
        case .direct: fresh.filter { directIDs.contains($0.id) }
        case .all: fresh
        }

        return NotifyPlan(
            toNotify: audible,
            notified: notified.intersection(present).union(candidates.map(\.id))
        )
    }
}
