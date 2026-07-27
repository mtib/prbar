import Foundation

/// Talks to GitHub through an already-authenticated `gh` CLI.
public struct GitHubClient: PullRequestSource {
    public enum Failure: Error, LocalizedError, Sendable {
        case ghNotFound([String])

        public var errorDescription: String? {
            switch self {
            case .ghNotFound(let searched):
                "GitHub CLI (gh) not found. Looked in: \(searched.joined(separator: ", "))"
            }
        }
    }

    /// A GUI app has no shell PATH, so `gh` is located by probing the usual install prefixes.
    static let candidatePaths = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "/usr/bin/gh",
        "/run/current-system/sw/bin/gh",
    ]

    private let ghPath: String
    private let runner: any CommandRunner

    public init(ghPath: String, runner: any CommandRunner = ProcessRunner()) {
        self.ghPath = ghPath
        self.runner = runner
    }

    public static func locate(runner: any CommandRunner = ProcessRunner()) throws -> GitHubClient {
        guard let path = candidatePaths.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else { throw Failure.ghNotFound(candidatePaths) }
        return GitHubClient(ghPath: path, runner: runner)
    }

    public var describedAuth: String { "gh CLI (\(ghPath))" }

    public func currentUser() async throws -> String {
        try await runner.run(ghPath, arguments: ["api", "user", "--jq", ".login"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func search(_ query: String) async throws -> [PullRequest] {
        let output = try await runner.run(ghPath, arguments: [
            "api", "--paginate", "--slurp", "-X", "GET", "search/issues",
            "-f", "per_page=100",
            "-f", "q=\(query)",
        ])
        let pages = try JSONDecoder.gitHub().decode([SearchResponse].self, from: Data(output.utf8))
        return pages.flatMap(\.items).map(\.pullRequest)
    }

    public func fetchQueue() async throws -> ReviewQueueSnapshot {
        let user = try await currentUser()
        async let direct = search(ReviewQuery.direct(user: user))
        async let requested = search(ReviewQuery.requested(user: user))
        return ReviewQueueSnapshot(
            user: user,
            queue: ReviewQueue.classify(
                direct: try await direct,
                requested: try await requested,
                user: user
            )
        )
    }
}
