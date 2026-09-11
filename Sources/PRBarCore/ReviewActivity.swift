import Foundation

/// One review the user submitted, reduced to the pull request it landed on and when.
public struct ReviewEvent: Sendable, Hashable, Codable {
    public let pullRequestID: String
    public let submittedAt: Date

    public init(pullRequestID: String, submittedAt: Date) {
        self.pullRequestID = pullRequestID
        self.submittedAt = submittedAt
    }
}

public struct DayCount: Sendable, Hashable, Identifiable {
    public let day: Date
    public let count: Int

    public var id: Date { day }

    public init(day: Date, count: Int) {
        self.day = day
        self.count = count
    }
}

/// Reviews the user submitted over the trailing window, bucketed by local calendar day.
///
/// A pull request reviewed three times in a day counts once — the number answers "how many
/// PRs did I get through today", not "how many times did I hit Submit".
public struct ReviewActivity: Sendable, Equatable {
    public let events: [ReviewEvent]

    public init(events: [ReviewEvent] = []) {
        self.events = events
    }

    public static let empty = ReviewActivity()

    public func distinctPullRequests(
        on day: Date,
        calendar: Calendar = .current
    ) -> Int {
        var seen = Set<String>()
        for event in events where calendar.isDate(event.submittedAt, inSameDayAs: day) {
            seen.insert(event.pullRequestID)
        }
        return seen.count
    }

    /// Counts for the last `days` calendar days, oldest first and including empty days.
    public func dailyCounts(
        days: Int,
        endingOn now: Date = .now,
        calendar: Calendar = .current
    ) -> [DayCount] {
        var byDay: [Date: Set<String>] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.submittedAt)
            byDay[day, default: []].insert(event.pullRequestID)
        }

        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayCount(day: day, count: byDay[day]?.count ?? 0)
        }
    }
}
