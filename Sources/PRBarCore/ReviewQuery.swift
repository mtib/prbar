/// The two GitHub searches the review queue is built from.
///
/// These qualifiers only resolve through the `search/issues` API — `gh search prs` silently
/// drops `review-requested:` and returns nothing. Unlike `/github-review-preview` we keep
/// drafts in the result set and split them out client-side, so the draft tab costs no extra
/// round trip.
public enum ReviewQuery {
    /// Review requested from the user personally.
    public static func direct(user: String) -> String {
        "is:pr is:open archived:false review:required user-review-requested:\(user)"
    }

    /// Review requested from the user *or* any team they belong to.
    public static func requested(user: String) -> String {
        "is:pr is:open archived:false review:required review-requested:\(user)"
    }
}
