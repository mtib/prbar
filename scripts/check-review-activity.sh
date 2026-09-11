#!/usr/bin/env bash
# Day-bucketing check for ReviewActivity. There is no test target (CLT ships no XCTest), so
# this compiles PRBarCore's object files against a throwaway main and asserts on fixed input.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build >/dev/null
BUILD=$(find .build -maxdepth 2 -type d -name debug | head -1)
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

cat > "$SCRATCH/check.swift" <<'SWIFT'
import Foundation
import PRBarCore

@main @MainActor struct Check {
    static var failures = 0

    static func expect(_ actual: Int, _ expected: Int, _ what: String) {
        if actual == expected {
            print("ok   \(what) == \(expected)")
        } else {
            print("FAIL \(what): expected \(expected), got \(actual)")
            failures += 1
        }
    }

    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen")!

        let noon = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 12))!
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(
                year: 2026, month: 9, day: day, hour: hour, minute: minute
            ))!
        }

        let activity = ReviewActivity(events: [
            ReviewEvent(pullRequestID: "a#1", submittedAt: at(11, 9)),
            ReviewEvent(pullRequestID: "a#1", submittedAt: at(11, 15)),
            ReviewEvent(pullRequestID: "a#2", submittedAt: at(11, 16)),
            ReviewEvent(pullRequestID: "a#3", submittedAt: at(11, 0, 30)),
            ReviewEvent(pullRequestID: "a#4", submittedAt: at(11, 23, 30)),
            ReviewEvent(pullRequestID: "a#5", submittedAt: at(10, 12)),
            ReviewEvent(pullRequestID: "a#6", submittedAt: at(4, 12)),
        ])

        expect(
            activity.distinctPullRequests(on: noon, calendar: calendar), 4,
            "today counts distinct PRs, not submissions"
        )

        let week = activity.dailyCounts(days: 7, endingOn: noon, calendar: calendar)
        expect(week.count, 7, "seven days returned")
        expect(week.last?.count ?? -1, 4, "today is last")
        expect(week.dropLast().last?.count ?? -1, 1, "yesterday")
        expect(week.filter { $0.count == 0 }.count, 5, "empty days are kept")
        expect(
            week.first.map { calendar.component(.day, from: $0.day) } ?? -1, 5,
            "oldest day of a 7-day window ending 11 Sep is 5 Sep"
        )

        // 4 Sep falls outside the 7-day window but inside a 30-day one.
        let month = activity.dailyCounts(days: 30, endingOn: noon, calendar: calendar)
        expect(month.reduce(0) { $0 + $1.count }, 6, "30-day total")

        // Same instants, +12 instead of +02: only the 00:30 and 09:00 reviews stay on the
        // same day, so a day boundary hard-coded to UTC would not produce 2 here.
        var auckland = calendar
        auckland.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        expect(
            activity.distinctPullRequests(on: noon, calendar: auckland), 2,
            "bucketing follows the supplied calendar's time zone"
        )

        print(failures == 0 ? "\nall checks passed" : "\n\(failures) check(s) failed")
        exit(failures == 0 ? 0 : 1)
    }
}
SWIFT

swiftc -swift-version 6 -parse-as-library \
    -I "$BUILD/Modules" "$SCRATCH/check.swift" "$BUILD"/PRBarCore.build/*.o \
    -o "$SCRATCH/check"
"$SCRATCH/check"
