import Foundation

/// How much of the queue is allowed to raise a banner.
public enum NotificationMode: String, Sendable, CaseIterable, Codable, Identifiable {
    case off
    case direct
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: "Off"
        case .direct: "Only direct"
        case .all: "All"
        }
    }

    public var symbol: String {
        switch self {
        case .off: "bell.slash"
        case .direct: "bell.badge"
        case .all: "bell"
        }
    }

    /// `all` is the resting state, so it is the only mode a timer can revert *to*.
    public var isMuted: Bool { self != .all }
}

/// How long a mute lasts before it lapses back to `all`.
public enum MuteDuration: String, Sendable, CaseIterable, Codable, Identifiable {
    case never
    case thirtyMinutes
    case oneHour
    case fourHours
    case eightHours

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .never: "Until I change it"
        case .thirtyMinutes: "30 minutes"
        case .oneHour: "1 hour"
        case .fourHours: "4 hours"
        case .eightHours: "8 hours"
        }
    }

    public var interval: TimeInterval? {
        switch self {
        case .never: nil
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        case .fourHours: 4 * 60 * 60
        case .eightHours: 8 * 60 * 60
        }
    }

    public func expiry(from start: Date) -> Date? {
        interval.map { start.addingTimeInterval($0) }
    }
}

/// How often the queue is re-fetched.
public enum PollInterval: String, Sendable, CaseIterable, Codable, Identifiable {
    case oneMinute
    case fiveMinutes
    case tenMinutes
    case thirtyMinutes
    case hourly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .oneMinute: "Every minute"
        case .fiveMinutes: "Every 5 minutes"
        case .tenMinutes: "Every 10 minutes"
        case .thirtyMinutes: "Every 30 minutes"
        case .hourly: "Every hour"
        }
    }

    public var seconds: TimeInterval {
        switch self {
        case .oneMinute: 60
        case .fiveMinutes: 5 * 60
        case .tenMinutes: 10 * 60
        case .thirtyMinutes: 30 * 60
        case .hourly: 60 * 60
        }
    }
}

/// Order of the PR lists, worded like GitHub's own sort menu.
public enum QueueSort: String, Sendable, CaseIterable, Codable, Identifiable {
    case recentlyUpdated
    case leastRecentlyUpdated
    case newest
    case oldest

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .recentlyUpdated: "Recently updated"
        case .leastRecentlyUpdated: "Least recently updated"
        case .newest: "Newest"
        case .oldest: "Oldest"
        }
    }

    /// The timestamp this order is based on, which is also the age a row should show.
    public func date(of pullRequest: PullRequest) -> Date {
        switch self {
        case .recentlyUpdated, .leastRecentlyUpdated: pullRequest.updatedAt
        case .newest, .oldest: pullRequest.createdAt
        }
    }

    public func sorted(_ pullRequests: [PullRequest]) -> [PullRequest] {
        let newestFirst: Bool = switch self {
        case .recentlyUpdated, .newest: true
        case .leastRecentlyUpdated, .oldest: false
        }
        return pullRequests.sorted {
            let (a, b) = (date(of: $0), date(of: $1))
            return a == b ? $0.id < $1.id : (newestFirst ? a > b : a < b)
        }
    }
}
