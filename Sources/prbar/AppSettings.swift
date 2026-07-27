import Foundation
import Observation
import PRBarCore

@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let authMode = "authMode"
    }

    private let defaults: UserDefaults
    private let tokenStore: KeychainTokenStore

    var authMode: AuthMode {
        didSet { defaults.set(authMode.rawValue, forKey: Key.authMode) }
    }

    /// Mirrors the Keychain so views can bind to it without hitting the Keychain per keystroke.
    private(set) var hasToken: Bool

    init(defaults: UserDefaults = .standard, tokenStore: KeychainTokenStore = KeychainTokenStore()) {
        self.defaults = defaults
        self.tokenStore = tokenStore
        self.authMode = defaults.string(forKey: Key.authMode)
            .flatMap(AuthMode.init(rawValue:)) ?? .automatic
        self.hasToken = tokenStore.load() != nil
    }

    func token() -> String? { tokenStore.load() }

    func saveToken(_ token: String) throws {
        try tokenStore.save(token.trimmingCharacters(in: .whitespacesAndNewlines))
        hasToken = true
    }

    func clearToken() throws {
        try tokenStore.delete()
        hasToken = false
    }

    func resolveSource() throws -> any PullRequestSource {
        try SourceResolver.resolve(mode: authMode, token: token())
    }
}
