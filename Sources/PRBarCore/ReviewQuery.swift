import Foundation

/// The two GitHub searches the review queue is built from.
///
/// These qualifiers only resolve through the `search/issues` API — `gh search prs` silently
/// drops `review-requested:` and returns nothing. Unlike `/github-review-preview` we keep
/// drafts in the result set and split them out client-side, so the draft tab costs no extra
/// round trip.
public enum ReviewQuery {
    /// Review requested from the user personally.
    public static func direct(user: String, filter: String = "") -> String {
        appending(
            filter,
            to: "is:pr is:open archived:false review:required user-review-requested:\(user)"
        )
    }

    /// Review requested from the user *or* any team they belong to.
    public static func requested(user: String, filter: String = "") -> String {
        appending(
            filter,
            to: "is:pr is:open archived:false review:required review-requested:\(user)"
        )
    }

    /// Appends user-supplied qualifiers verbatim. Nothing is validated here: GitHub answers a
    /// malformed qualifier with a 422, which surfaces as the panel's error line.
    private static func appending(_ filter: String, to query: String) -> String {
        let extra = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        return extra.isEmpty ? query : "\(query) \(extra)"
    }
}
