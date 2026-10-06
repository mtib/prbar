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
        let child = ChildProcess()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .utility) {
                try Self.runSync(executable, arguments, timeout: timeout, child: child)
            }.value
        } onCancel: {
            child.terminate(.cancelled)
        }
    }

    /// Lets the watchdog and task cancellation reach a process that is started on another thread.
    private final class ChildProcess: @unchecked Sendable {
        enum Reason { case timedOut, cancelled }

        private let lock = NSLock()
        private var process: Process?
        private var reason: Reason?

        var terminationReason: Reason? {
            lock.withLock { reason }
        }

        func attach(_ process: Process) {
            lock.withLock {
                self.process = process
                if reason != nil { process.terminate() }
            }
        }

        func terminate(_ why: Reason) {
            lock.withLock {
                if reason == nil { reason = why }
                if process?.isRunning == true { process?.terminate() }
            }
        }
    }

    /// Closes the output handles explicitly: `FileHandle(forWritingTo:)` does not close its
    /// descriptor on dealloc, and leaking two per call exhausts the 256-descriptor soft limit.
    private static func runSync(
        _ executable: String,
        _ arguments: [String],
        timeout: TimeInterval,
        child: ChildProcess
    ) throws -> String {
        let scratch = FileManager.default.temporaryDirectory
            .appending(path: "prbar-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let outURL = scratch.appending(path: "stdout")
        let errURL = scratch.appending(path: "stderr")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)

        let outHandle = try FileHandle(forWritingTo: outURL)
        let errHandle = try FileHandle(forWritingTo: errURL)
        defer {
            try? outHandle.close()
            try? errHandle.close()
        }

        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = outHandle
        process.standardError = errHandle

        var environment = ProcessInfo.processInfo.environment
        let path = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = (extraPath + [path]).joined(separator: ":")
        process.environment = environment

        try process.run()
        child.attach(process)

        let watchdog = DispatchWorkItem { child.terminate(.timedOut) }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)
        process.waitUntilExit()
        watchdog.cancel()

        let command = ([executable] + arguments).joined(separator: " ")
        switch child.terminationReason {
        case .timedOut:
            throw CommandFailure(
                command: command,
                exitCode: process.terminationStatus,
                stderr: "timed out after \(Int(timeout))s"
            )
        case .cancelled:
            throw CancellationError()
        case nil:
            break
        }

        guard process.terminationStatus == 0 else {
            let err = (try? Data(contentsOf: errURL)) ?? Data()
            throw CommandFailure(
                command: command,
                exitCode: process.terminationStatus,
                stderr: String(decoding: err, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return String(decoding: (try? Data(contentsOf: outURL)) ?? Data(), as: UTF8.self)
    }
}
