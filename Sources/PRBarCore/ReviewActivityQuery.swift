import Foundation

/// The GraphQL half of a backend. Both `gh api graphql` and a POST to `/graphql` reduce to
/// "send a document plus string variables, get JSON back".
public protocol GraphQLTransport: Sendable {
    func graphQL(document: String, variables: [String: String]) async throws -> Data
}

/// Fetches the user's own review history.
///
/// `contributionsCollection` would be the obvious source and is unusable: its
/// `pullRequestReviewContributions` silently drops everything in private repositories, which
/// is nearly all of them. Searching `reviewed-by:` and pulling each PR's reviews back in the
/// same round trip sees private work and carries the real `submittedAt` per review. The
/// `updated:` bound is a safe superset — submitting a review bumps the PR's updated stamp, so
/// no review inside the window can hide behind an older one.
public enum ReviewActivityQuery {
    /// search/issues caps at 1000 results; 10 pages of 100 reaches that ceiling.
    static let maxPages = 10
    static let pageSize = 100

    public static func search(user: String, since: Date) -> String {
        let day = since.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "is:pr reviewed-by:\(user) updated:>=\(day)"
    }

    static let document = """
    query($q: String!, $author: String!, $after: String) {
      search(query: $q, type: ISSUE, first: \(pageSize), after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          ... on PullRequest {
            number
            repository { nameWithOwner }
            reviews(last: 30, author: $author) { nodes { submittedAt } }
          }
        }
      }
    }
    """

    public static func fetch(
        from transport: any GraphQLTransport,
        user: String,
        since: Date
    ) async throws -> ReviewActivity {
        var variables = ["q": search(user: user, since: since), "author": user]
        var events: [ReviewEvent] = []

        for _ in 0..<maxPages {
            let data = try await transport.graphQL(document: document, variables: variables)
            let page = try JSONDecoder.graphQL().decode(Envelope.self, from: data)
            if let failure = page.errors?.first?.message {
                throw GraphQLFailure(message: failure)
            }
            guard let search = page.data?.search else { break }

            for node in search.nodes {
                guard let repo = node.repository?.nameWithOwner, let number = node.number else { continue }
                let id = "\(repo)#\(number)"
                for review in node.reviews?.nodes ?? [] {
                    guard let submittedAt = review.submittedAt, submittedAt >= since else { continue }
                    events.append(ReviewEvent(pullRequestID: id, submittedAt: submittedAt))
                }
            }

            guard search.pageInfo.hasNextPage, let cursor = search.pageInfo.endCursor else { break }
            variables["after"] = cursor
        }
        return ReviewActivity(events: events)
    }
}

public struct GraphQLFailure: Error, LocalizedError, Sendable {
    public let message: String
    public var errorDescription: String? { "GitHub GraphQL: \(message)" }
}

private struct Envelope: Decodable {
    struct Message: Decodable { let message: String }
    struct Payload: Decodable { let search: SearchPage? }
    struct SearchPage: Decodable {
        let pageInfo: PageInfo
        let nodes: [Node]
    }
    struct PageInfo: Decodable {
        let hasNextPage: Bool
        let endCursor: String?
    }
    struct Node: Decodable {
        struct Repository: Decodable { let nameWithOwner: String }
        struct Reviews: Decodable { let nodes: [Review]? }
        struct Review: Decodable { let submittedAt: Date? }

        let number: Int?
        let repository: Repository?
        let reviews: Reviews?
    }

    let data: Payload?
    let errors: [Message]?
}

extension JSONDecoder {
    static func graphQL() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
