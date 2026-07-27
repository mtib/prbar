import Foundation

public struct CommandFailure: Error, LocalizedError, Sendable {
    public let command: String
    public let exitCode: Int32
    public let stderr: String

    public var errorDescription: String? {
        let detail = stderr.isEmpty ? "exit \(exitCode)" : stderr
        return "\(command): \(detail)"
    }
}

public protocol CommandRunner: Sendable {
    func run(_ executable: String, arguments: [String]) async throws -> String
}

/// Runs a child process off the calling actor, buffering its output through temp files so a
/// chatty child can never deadlock on a full pipe.
public struct ProcessRunner: CommandRunner {
    /// A menu bar app launched from Finder inherits only the system PATH, but `gh` shells out
    /// to `git` and friends.
    private static let extraPath = ["/opt/homebrew/bin", "/usr/local/bin"]

    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 60) {
        self.timeout = timeout
    }

    public func run(_ executable: String, arguments: [String]) async throws -> String {
        let timeout = timeout
        return try await Task.detached(priority: .utility) {
            try Self.runSync(executable, arguments, timeout: timeout)
        }.value
    }

    private final class ProcessBox: @unchecked Sendable {
        let process: Process
        init(_ process: Process) { self.process = process }
    }

    private static func runSync(
        _ executable: String,
        _ arguments: [String],
        timeout: TimeInterval
    ) throws -> String {
        let scratch = FileManager.default.temporaryDirectory
            .appending(path: "prbar-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let outURL = scratch.appending(path: "stdout")
        let errURL = scratch.appending(path: "stderr")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)

        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = try FileHandle(forWritingTo: outURL)
        process.standardError = try FileHandle(forWritingTo: errURL)

        var environment = ProcessInfo.processInfo.environment
        let path = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = (extraPath + [path]).joined(separator: ":")
        process.environment = environment

        try process.run()

        let box = ProcessBox(process)
        let watchdog = DispatchWorkItem {
            if box.process.isRunning { box.process.terminate() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)
        process.waitUntilExit()
        watchdog.cancel()

        let out = (try? Data(contentsOf: outURL)) ?? Data()
        guard process.terminationStatus == 0 else {
            let err = (try? Data(contentsOf: errURL)) ?? Data()
            throw CommandFailure(
                command: ([executable] + arguments).joined(separator: " "),
                exitCode: process.terminationStatus,
                stderr: String(decoding: err, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return String(decoding: out, as: UTF8.self)
    }
}
