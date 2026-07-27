import Foundation

/// Talks to api.github.com directly with a personal access token — no `gh` install needed.
public struct GitHubTokenClient: PullRequestSource {
    public struct APIFailure: Error, LocalizedError, Sendable {
        public let statusCode: Int
        public let body: String

        public var errorDescription: String? {
            let hint = switch statusCode {
            case 401: " — token rejected; check it hasn't expired"
            case 403: " — forbidden or rate limited"
            case 422: " — GitHub rejected the search query"
            default: ""
            }
            return "GitHub API \(statusCode)\(hint): \(body.prefix(300))"
        }
    }

    /// A classic PAT needs `repo` + `read:org` to see private repos and team review requests.
    public static let requiredScopes = "repo, read:org"

    private static let apiRoot = URL(string: "https://api.github.com")!
    private static let pageSize = 100
    /// search/issues caps out at 1000 results; stop well before spinning forever.
    private static let maxPages = 10

    private let token: String
    private let session: URLSession

    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    public var describedAuth: String { "access token (…\(token.suffix(4)))" }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("prbar", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func get(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request(url))
        guard let http = response as? HTTPURLResponse else {
            throw APIFailure(statusCode: -1, body: "non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIFailure(
                statusCode: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
        return (data, http)
    }

    public func currentUser() async throws -> String {
        struct Me: Decodable { let login: String }
        let (data, _) = try await get(Self.apiRoot.appending(path: "user"))
        return try JSONDecoder().decode(Me.self, from: data).login
    }

    public func search(_ query: String) async throws -> [PullRequest] {
        var components = URLComponents(
            url: Self.apiRoot.appending(path: "search/issues"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: String(Self.pageSize)),
        ]

        var next: URL? = components.url
        var items: [PullRequest] = []
        let decoder = JSONDecoder.gitHub()

        for _ in 0..<Self.maxPages {
            guard let url = next else { break }
            let (data, http) = try await get(url)
            items += try decoder.decode(SearchResponse.self, from: data).items.map(\.pullRequest)
            next = Self.nextPageURL(linkHeader: http.value(forHTTPHeaderField: "Link"))
        }
        return items
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

    /// Extracts the `rel="next"` target from an RFC 5988 `Link` header.
    static func nextPageURL(linkHeader: String?) -> URL? {
        guard let linkHeader else { return nil }
        for link in linkHeader.split(separator: ",") {
            let parts = link.split(separator: ";").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count >= 2,
                  parts.dropFirst().contains(where: { $0.contains("rel=\"next\"") }),
                  let target = parts.first,
                  target.hasPrefix("<"), target.hasSuffix(">")
            else { continue }
            return URL(string: String(target.dropFirst().dropLast()))
        }
        return nil
    }
}
