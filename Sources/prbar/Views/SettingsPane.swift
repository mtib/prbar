import PRBarCore
import SwiftUI

struct SettingsPane: View {
    private let model: AppModel
    @Bindable private var settings: AppSettings

    @State private var tokenDraft = ""
    @State private var status: Status?

    init(model: AppModel) {
        self.model = model
        _settings = Bindable(model.settings)
    }

    private enum Status: Equatable {
        case checking
        case ok(String)
        case failed(String)
    }

    var body: some View {
        Form {
            Section {
                Picker("Authenticate with", selection: $settings.authMode) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text(authHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Personal access token") {
                SecureField("ghp_… or github_pat_…", text: $tokenDraft)
                    .onSubmit(save)
                HStack {
                    Button("Save", action: save)
                        .disabled(tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove", action: clear)
                        .disabled(!settings.hasToken)
                    Spacer()
                    Button("Test connection", action: test)
                }
                Text(settings.hasToken
                    ? "A token is saved in your Keychain. Needs scopes: \(GitHubTokenClient.requiredScopes)."
                    : "No token saved. Needs scopes: \(GitHubTokenClient.requiredScopes).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let status {
                Section {
                    switch status {
                    case .checking:
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Checking…")
                        }
                    case .ok(let message):
                        Label(message, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failed(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var authHint: String {
        switch settings.authMode {
        case .automatic: "Uses a saved token when present, otherwise the gh CLI."
        case .ghCLI: "Shells out to gh, reusing whatever account gh is logged in as."
        case .token: "Calls api.github.com directly. No gh install required."
        }
    }

    private func save() {
        do {
            try settings.saveToken(tokenDraft)
            tokenDraft = ""
            status = .ok("Token saved.")
            model.refresh()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func clear() {
        do {
            try settings.clearToken()
            status = .ok("Token removed.")
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func test() {
        status = .checking
        Task {
            do {
                let source = try settings.resolveSource()
                let snapshot = try await source.fetchQueue()
                status = .ok(
                    """
                    \(snapshot.user) via \(source.describedAuth) — \
                    \(snapshot.queue.direct.count) direct, \
                    \(snapshot.queue.team.count) team, \
                    \(snapshot.queue.drafts.count) draft
                    """
                )
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }
}
