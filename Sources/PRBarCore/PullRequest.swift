import Foundation

/// A pull request as returned by GitHub's `search/issues` API, flattened to the fields
/// the menu bar needs. `id` doubles as the stable notify-once key.
public struct PullRequest: Sendable, Hashable, Identifiable {
    public let repo: String
    public let number: Int
    public let title: String
    public let url: URL
    public let author: String
    public let isDraft: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public var id: String { "\(repo)#\(number)" }

    /// Repo name without the owner — what fits in a notification banner.
    public var service: String { repo.split(separator: "/").last.map(String.init) ?? repo }

    public init(
        repo: String,
        number: Int,
        title: String,
        url: URL,
        author: String,
        isDraft: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.repo = repo
        self.number = number
        self.title = title
        self.url = url
        self.author = author
        self.isDraft = isDraft
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
