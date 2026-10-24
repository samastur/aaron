import Foundation

public struct ProcessResult: Sendable, Equatable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32
}

public enum ProcessError: Error, Equatable, LocalizedError {
    case launchFailed(String)
    case failed(exitCode: Int32, stderr: String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let reason): "The command could not be started: \(reason)"
        case .failed(let code, let stderr):
            stderr.isEmpty ? "The command failed with exit status \(code)."
                : "The command failed with exit status \(code):\n\(stderr)"
        case .timedOut: "The command did not finish in time and was stopped."
        }
    }
}

/// Runs user-configured shell commands.
///
/// Commands run through `/bin/zsh -c` (as a login shell by default) so the
/// user's `PATH` applies; apps started from Finder don't inherit it.
public struct ProcessRunner: Sendable {
    public static let defaultExtraPath: [String] = [
        NSHomeDirectory() + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin",
    ]

    public var shell: String
    public var loginShell: Bool
    public var extraPath: [String]

    public init(shell: String = "/bin/zsh", loginShell: Bool = true,
                extraPath: [String] = ProcessRunner.defaultExtraPath) {
        self.shell = shell
        self.loginShell = loginShell
        self.extraPath = extraPath
    }

    /// Runs `command`, feeding `input` on stdin. Throws `ProcessError` for a
    /// nonzero exit or timeout and `CancellationError` when the task is
    /// cancelled; the process is terminated in both cases.
    public func run(_ command: String, input: String? = nil, workingDirectory: URL? = nil,
                    timeout: Duration) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = (loginShell ? ["-l"] : []) + ["-c", command]
        // Apps started from Finder run in "/"; the home folder is a saner default.
        process.currentDirectoryURL = workingDirectory ?? URL(fileURLWithPath: NSHomeDirectory())
        process.environment = environment()

        let stdout = Pipe(), stderr = Pipe(), stdin = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = stdin

        let state = RunState()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessResult, Error>) in
                state.setContinuation(continuation)
                let group = DispatchGroup()
                for (pipe, isOut) in [(stdout, true), (stderr, false)] {
                    group.enter()
                    DispatchQueue.global().async {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        state.store(data, stdout: isOut)
                        group.leave()
                    }
                }
                process.terminationHandler = { finished in
                    group.notify(queue: .global()) {
                        state.finish(exitCode: finished.terminationStatus)
                    }
                }
                do {
                    try process.run()
                } catch {
                    state.fail(ProcessError.launchFailed(error.localizedDescription))
                    return
                }
                state.setProcess(process)
                DispatchQueue.global().async {
                    let handle = stdin.fileHandleForWriting
                    if let input { try? handle.write(contentsOf: Data(input.utf8)) }
                    try? handle.close()
                }
                let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
                DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                    state.fail(ProcessError.timedOut)
                }
            }
        } onCancel: {
            state.fail(CancellationError())
        }
    }

    func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let existing = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = (extraPath + [existing]).joined(separator: ":")
        return env
    }
}

/// Shared state between the pipe readers, the termination handler, the
/// timeout and cancellation. The continuation is resumed exactly once.
private final class RunState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ProcessResult, Error>?
    private var process: Process?
    private var stdout = Data()
    private var stderr = Data()
    private var pendingError: Error?
    private var done = false

    func setContinuation(_ c: CheckedContinuation<ProcessResult, Error>) {
        lock.lock()
        if let pendingError {
            done = true
            lock.unlock()
            c.resume(throwing: pendingError)
            return
        }
        continuation = c
        lock.unlock()
    }

    func setProcess(_ p: Process) {
        lock.lock()
        process = p
        let alreadyDone = done
        lock.unlock()
        if alreadyDone && p.isRunning { p.terminate() }
    }

    func store(_ data: Data, stdout isOut: Bool) {
        lock.lock()
        if isOut { stdout = data } else { stderr = data }
        lock.unlock()
    }

    func finish(exitCode: Int32) {
        lock.lock()
        guard !done, let c = continuation else { lock.unlock(); return }
        done = true
        let out = String(decoding: stdout, as: UTF8.self)
        let err = String(decoding: stderr, as: UTF8.self)
        lock.unlock()
        if exitCode == 0 {
            c.resume(returning: ProcessResult(stdout: out, stderr: err, exitCode: exitCode))
        } else {
            c.resume(throwing: ProcessError.failed(
                exitCode: exitCode, stderr: err.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }

    func fail(_ error: Error) {
        lock.lock()
        guard !done else { lock.unlock(); return }
        guard let c = continuation else {
            // Cancelled before the continuation existed.
            pendingError = error
            lock.unlock()
            return
        }
        done = true
        let p = process
        lock.unlock()
        if let p, p.isRunning { p.terminate() }
        c.resume(throwing: error)
    }
}
