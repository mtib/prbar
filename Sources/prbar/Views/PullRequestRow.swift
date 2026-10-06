import PRBarCore
import SwiftUI

struct PullRequestRow: View {
    let pullRequest: PullRequest
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pullRequest.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    Text(verbatim: "#\(pullRequest.number)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 6) {
                    Text(pullRequest.repo)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Text(pullRequest.author)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(pullRequest.updatedAt, format: .relative(presentation: .numeric))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(pullRequest.url.absoluteString)
    }
}
