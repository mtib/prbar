import Foundation

/// Plausible review-queue content for README screenshots, generated relative to `now` so the
/// ages always look fresh.
public enum MockData {
    public static let user = "octocat"

    private static func pr(
        _ repo: String, _ number: Int, _ title: String, by author: String,
        createdHoursAgo: Double, updatedHoursAgo: Double, draft: Bool = false, now: Date
    ) -> PullRequest {
        PullRequest(
            repo: repo,
            number: number,
            title: title,
            url: URL(string: "https://github.com/\(repo)/pull/\(number)")!,
            author: author,
            isDraft: draft,
            createdAt: now.addingTimeInterval(-createdHoursAgo * 3600),
            updatedAt: now.addingTimeInterval(-updatedHoursAgo * 3600)
        )
    }

    public static func queue(now: Date = .now) -> ReviewQueue {
        ReviewQueue(
            direct: [
                pr("acme/api", 4821, "Retry webhook delivery with exponential backoff", by: "mona", createdHoursAgo: 5, updatedHoursAgo: 0.4, now: now),
                pr("acme/web", 1307, "Fix focus trap in the checkout dialog", by: "hubot", createdHoursAgo: 29, updatedHoursAgo: 3, now: now),
                pr("acme/infra", 912, "Move staging cluster to the new node pool", by: "ada", createdHoursAgo: 52, updatedHoursAgo: 11, now: now),
                pr("acme/api", 4798, "Add pagination to the invoices endpoint", by: "linus", createdHoursAgo: 120, updatedHoursAgo: 26, now: now),
            ],
            team: [
                pr("acme/mobile", 2210, "Cache charger map tiles between sessions", by: "grace", createdHoursAgo: 8, updatedHoursAgo: 1.2, now: now),
                pr("acme/web", 1311, "Replace moment with date-fns in the billing views", by: "tim", createdHoursAgo: 20, updatedHoursAgo: 6, now: now),
                pr("acme/docs", 640, "Document the OCPI 2.2.1 roaming flow", by: "margaret", createdHoursAgo: 70, updatedHoursAgo: 22, now: now),
                pr("acme/api", 4802, "Stop logging full request bodies on 4xx", by: "dennis", createdHoursAgo: 96, updatedHoursAgo: 40, now: now),
                pr("acme/infra", 905, "Bump Terraform AWS provider to 6.x", by: "ken", createdHoursAgo: 200, updatedHoursAgo: 90, now: now),
            ],
            drafts: [
                pr("acme/web", 1315, "WIP: dark mode for the partner portal", by: "mona", createdHoursAgo: 14, updatedHoursAgo: 2, draft: true, now: now),
                pr("acme/api", 4830, "Draft: rate limit per API key", by: "ada", createdHoursAgo: 30, updatedHoursAgo: 9, draft: true, now: now),
            ]
        )
    }

    public static func activity(now: Date = .now, calendar: Calendar = .current) -> ReviewActivity {
        let perDay = [4, 2, 5, 0, 0, 3, 6, 1, 4, 5, 2, 0, 0, 3, 7, 4, 2, 6, 3, 1, 0, 0, 5, 4, 3, 6, 2, 4, 3, 1]
        let today = calendar.startOfDay(for: now)
        var events: [ReviewEvent] = []
        for (offset, count) in perDay.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            for index in 0..<count {
                let at = min(day.addingTimeInterval(Double(9 + index) * 3600), now)
                events.append(ReviewEvent(pullRequestID: "mock/\(offset)#\(index)", submittedAt: at))
            }
        }
        return ReviewActivity(events: events)
    }
}
