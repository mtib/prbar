import Foundation

public struct ReviewQueueSnapshot: Sendable, Equatable {
    public let user: String
    public let queue: ReviewQueue

    public init(user: String, queue: ReviewQueue) {
        self.user = user
        self.queue = queue
    }
}

/// Where the review queue comes from — the `gh` CLI or api.github.com with a token.
public protocol PullRequestSource: Sendable {
    var describedAuth: String { get }
    func fetchQueue() async throws -> ReviewQueueSnapshot
}

public enum AuthMode: String, Sendable, CaseIterable, Identifiable, Codable {
    /// Prefer a stored token, fall back to the `gh` CLI.
    case automatic
    case ghCLI
    case token

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case .ghCLI: "GitHub CLI (gh)"
        case .token: "Access token"
        }
    }
}

public enum SourceResolutionError: Error, LocalizedError, Sendable {
    case noTokenStored
    case ghUnavailable(any Error)

    public var errorDescription: String? {
        switch self {
        case .noTokenStored:
            "No access token saved. Add one in Settings, or install the GitHub CLI."
        case .ghUnavailable(let underlying):
            underlying.localizedDescription
        }
    }
}

public enum SourceResolver {
    /// Picks a source for `mode`. `automatic` prefers a stored token because it needs no
    /// external binary, then falls back to whatever `gh` is already authenticated as.
    public static func resolve(mode: AuthMode, token: String?) throws -> any PullRequestSource {
        let token = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        let usableToken = (token?.isEmpty == false) ? token : nil

        switch mode {
        case .token:
            guard let usableToken else { throw SourceResolutionError.noTokenStored }
            return GitHubTokenClient(token: usableToken)
        case .ghCLI:
            do { return try GitHubClient.locate() } catch { throw SourceResolutionError.ghUnavailable(error) }
        case .automatic:
            if let usableToken { return GitHubTokenClient(token: usableToken) }
            do { return try GitHubClient.locate() } catch { throw SourceResolutionError.ghUnavailable(error) }
        }
    }
}
