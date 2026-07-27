import Foundation

/// Persists the notify-once keys so restarting the app doesn't re-announce the queue.
public struct NotifyStateStore: Sendable {
    private struct State: Codable {
        var notified: [String]
    }

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func inApplicationSupport(
        bundleName: String = "prbar",
        fileManager: FileManager = .default
    ) -> NotifyStateStore {
        let base = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support")
        return NotifyStateStore(
            fileURL: base.appending(path: bundleName).appending(path: "notified.json")
        )
    }

    /// `nil` means "never polled before", which callers treat as a silent seed.
    public func load() -> Set<String>? {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return nil }
        return Set(state.notified)
    }

    public func save(_ notified: Set<String>) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(State(notified: notified.sorted()))
        try data.write(to: fileURL, options: .atomic)
    }
}
