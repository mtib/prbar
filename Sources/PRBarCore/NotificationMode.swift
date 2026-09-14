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
