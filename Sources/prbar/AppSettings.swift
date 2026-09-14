import Foundation
import Observation
import PRBarCore

@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let authMode = "authMode"
        static let notificationMode = "notificationMode"
        static let muteDuration = "muteDuration"
        static let muteExpiry = "muteExpiry"
    }

    private let defaults: UserDefaults
    private let tokenStore: KeychainTokenStore

    var authMode: AuthMode {
        didSet { defaults.set(authMode.rawValue, forKey: Key.authMode) }
    }

    /// Mirrors the Keychain so views can bind to it without hitting the Keychain per keystroke.
    private(set) var hasToken: Bool

    /// Muting always carries an explicit deadline or none at all, so the stored expiry is the
    /// single source of truth — `muteDuration` is only remembered so the next mute defaults to
    /// the same length.
    var notificationMode: NotificationMode {
        didSet {
            defaults.set(notificationMode.rawValue, forKey: Key.notificationMode)
            restartMuteTimer()
        }
    }

    var muteDuration: MuteDuration {
        didSet {
            defaults.set(muteDuration.rawValue, forKey: Key.muteDuration)
            restartMuteTimer()
        }
    }

    private(set) var muteExpiry: Date? {
        didSet {
            if let muteExpiry {
                defaults.set(muteExpiry.timeIntervalSinceReferenceDate, forKey: Key.muteExpiry)
            } else {
                defaults.removeObject(forKey: Key.muteExpiry)
            }
        }
    }

    init(defaults: UserDefaults = .standard, tokenStore: KeychainTokenStore = KeychainTokenStore()) {
        self.defaults = defaults
        self.tokenStore = tokenStore
        self.authMode = defaults.string(forKey: Key.authMode)
            .flatMap(AuthMode.init(rawValue:)) ?? .automatic
        self.notificationMode = defaults.string(forKey: Key.notificationMode)
            .flatMap(NotificationMode.init(rawValue:)) ?? .all
        self.muteDuration = defaults.string(forKey: Key.muteDuration)
            .flatMap(MuteDuration.init(rawValue:)) ?? .never
        self.muteExpiry = defaults.object(forKey: Key.muteExpiry)
            .flatMap { $0 as? TimeInterval }
            .map(Date.init(timeIntervalSinceReferenceDate:))
        self.hasToken = tokenStore.load() != nil
        expireMuteIfDue()
    }

    /// Drops a lapsed mute, returning to `all`. Driven by the poll loop, so a mute can be up to
    /// one poll late — the deadline is a courtesy, not a guarantee.
    func expireMuteIfDue(now: Date = .now) {
        guard let muteExpiry, now >= muteExpiry else { return }
        self.muteExpiry = nil
        notificationMode = .all
    }

    private func restartMuteTimer() {
        muteExpiry = notificationMode.isMuted ? muteDuration.expiry(from: .now) : nil
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
