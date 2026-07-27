import Foundation

public enum ReviewBucket: String, Sendable, CaseIterable, Codable, Identifiable {
    case direct
    case team
    case draft

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .direct: "Direct"
        case .team: "Team"
        case .draft: "Drafts"
        }
    }
}

public struct ReviewQueue: Sendable, Equatable {
    public var direct: [PullRequest]
    public var team: [PullRequest]
    public var drafts: [PullRequest]

    public init(direct: [PullRequest] = [], team: [PullRequest] = [], drafts: [PullRequest] = []) {
        self.direct = direct
        self.team = team
        self.drafts = drafts
    }

    public static let empty = ReviewQueue()

    public subscript(bucket: ReviewBucket) -> [PullRequest] {
        switch bucket {
        case .direct: direct
        case .team: team
        case .draft: drafts
        }
    }

    /// Every PR in the queue, regardless of bucket.
    public var all: [PullRequest] { direct + team + drafts }

    /// PRs eligible for a notification — drafts never are.
    public var notifiable: [PullRequest] { direct + team }

    /// Splits the two search results into the three buckets.
    ///
    /// A PR the user authored is dropped entirely: GitHub cannot request a review from the
    /// author, so anything self-authored here arrived via a team request and is only noise.
    /// Drafts win over direct/team so a work-in-progress never lands in a notifying bucket.
    public static func classify(
        direct: [PullRequest],
        requested: [PullRequest],
        user: String
    ) -> ReviewQueue {
        let me = user.lowercased()
        let directIDs = Set(direct.map(\.id))

        var unique: [String: PullRequest] = [:]
        for pr in requested + direct where pr.author.lowercased() != me {
            unique[pr.id] = pr
        }

        var queue = ReviewQueue()
        for pr in unique.values {
            if pr.isDraft {
                queue.drafts.append(pr)
            } else if directIDs.contains(pr.id) {
                queue.direct.append(pr)
            } else {
                queue.team.append(pr)
            }
        }

        let newestFirst = { (a: PullRequest, b: PullRequest) in a.updatedAt > b.updatedAt }
        queue.direct.sort(by: newestFirst)
        queue.team.sort(by: newestFirst)
        queue.drafts.sort(by: newestFirst)
        return queue
    }
}
