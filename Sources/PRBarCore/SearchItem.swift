import Foundation

/// The subset of a `search/issues` item both backends map to `PullRequest`.
struct SearchItem: Decodable, Sendable {
    struct User: Decodable, Sendable {
        let login: String
    }

    let number: Int
    let title: String
    let htmlUrl: URL
    let repositoryUrl: String
    let user: User
    let draft: Bool?
    let createdAt: Date
    let updatedAt: Date

    var pullRequest: PullRequest {
        PullRequest(
            repo: repositoryUrl.replacingOccurrences(
                of: "https://api.github.com/repos/",
                with: ""
            ),
            number: number,
            title: title,
            url: htmlUrl,
            author: user.login,
            isDraft: draft ?? false,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct SearchResponse: Decodable, Sendable {
    let items: [SearchItem]
}

extension JSONDecoder {
    static func gitHub() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
