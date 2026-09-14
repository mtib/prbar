import PRBarCore
import SwiftUI

struct PanelView: View {
    @Bindable var model: AppModel

    @State private var showingActivity = false

    var body: some View {
        VStack(spacing: 0) {
            header
            bucketRow
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 420, height: 520)
    }

    private var header: some View {
        HStack {
            Text("Review queue")
                .font(.headline)
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            if !model.isOnline {
                Label("Offline", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.accessoryBar)
            .help("Refresh now")
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var bucketRow: some View {
        HStack(spacing: 8) {
            Picker("", selection: $model.selectedBucket) {
                ForEach(ReviewBucket.allCases) { bucket in
                    Text("\(bucket.title) (\(model.count(bucket)))").tag(bucket)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            activityButton
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onChange(of: model.selectedBucket) { showingActivity = false }
    }

    private var activityButton: some View {
        Button {
            showingActivity.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "message")
                Text("\(model.reviewedToday)")
                    .monospacedDigit()
            }
        }
        .buttonStyle(.accessoryBar)
        .foregroundStyle(showingActivity ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        .help("PRs you reviewed today — click for the last 7 or 30 days")
    }

    @ViewBuilder
    private var list: some View {
        if showingActivity {
            ReviewActivityPanel(model: model)
        } else {
            queueList
        }
    }

    @ViewBuilder
    private var queueList: some View {
        let pullRequests = model.queue[model.selectedBucket]
        if let error = model.lastError, pullRequests.isEmpty {
            emptyState(
                symbol: "exclamationmark.triangle",
                title: "Couldn't reach GitHub",
                detail: error
            )
        } else if pullRequests.isEmpty {
            emptyState(
                symbol: "checkmark.circle",
                title: "Nothing here",
                detail: emptyDetail(for: model.selectedBucket)
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(pullRequests) { pullRequest in
                        PullRequestRow(pullRequest: pullRequest) { model.open(pullRequest) }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
        }
    }

    private func emptyDetail(for bucket: ReviewBucket) -> String {
        switch bucket {
        case .direct: "No review is blocked on you personally."
        case .team: "No open review requests for your teams."
        case .draft: "No drafts are waiting on you or your teams."
        }
    }

    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.callout.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A mute you cannot see is a trap — you would just conclude the app had broken — so the
    /// footer always carries the current mode, and changing it takes one click.
    private var notificationMenu: some View {
        Menu {
            ForEach(NotificationMode.allCases) { mode in
                Button {
                    model.settings.notificationMode = mode
                } label: {
                    if mode == model.settings.notificationMode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        } label: {
            Image(systemName: model.settings.notificationMode.symbol)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(model.settings.notificationMode.isMuted ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
        .help(muteHelp)
    }

    private var muteHelp: String {
        let mode = model.settings.notificationMode
        guard mode.isMuted else { return "Notifications: \(mode.title)" }
        guard let expiry = model.settings.muteExpiry else {
            return "Notifications: \(mode.title) until you change it"
        }
        return "Notifications: \(mode.title) until \(expiry.formatted(.dateTime.hour().minute()))"
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Group {
                if let lastRefresh = model.lastRefresh {
                    Text("Updated \(lastRefresh, format: .relative(presentation: .numeric))")
                } else {
                    Text("Not refreshed yet")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let user = model.user {
                Text("· \(user)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            notificationMenu

            SettingsLink {
                Text("Settings…")
            }
            .buttonStyle(.accessoryBar)
            .simultaneousGesture(TapGesture().onEnded {
                NSApplication.shared.activate()
            })

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.accessoryBar)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
