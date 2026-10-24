import Darwin
import Foundation
import os

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
/// user's `PATH` applies; apps started from Finder don't inherit it. Each
/// command gets its own process group, so a timeout or cancellation stops
/// everything it started, not just the shell.
public struct ProcessRunner: Sendable {
    public static let defaultExtraPath: [String] = [
        NSHomeDirectory() + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin",
    ]

    /// How long to keep reading output after the command exited, in case a
    /// background process it left behind still holds the output open.
    static let outputGracePeriod: DispatchTimeInterval = .seconds(1)
    /// How long processes get to exit after SIGTERM before SIGKILL.
    static let killGracePeriod: TimeInterval = 2

    public var shell: String
    public var loginShell: Bool
    public var extraPath: [String]

    public init(shell: String = "/bin/zsh", loginShell: Bool = true,
                extraPath: [String] = ProcessRunner.defaultExtraPath) {
        self.shell = shell
        self.loginShell = loginShell
        self.extraPath = extraPath
        Self.ignoreSIGPIPE
    }

    /// Writing to a command that exited without reading its input must
    /// fail with EPIPE instead of killing the app.
    private static let ignoreSIGPIPE: Void = {
        signal(SIGPIPE, SIG_IGN)
    }()

    /// Runs `command`, feeding `input` on stdin. Throws `ProcessError` for a
    /// nonzero exit, launch failure or timeout, and `CancellationError` when
    /// the task is cancelled; the command's processes are stopped in both
    /// latter cases. A timeout below one second counts as one second.
    public func run(_ command: String, input: String? = nil, workingDirectory: URL? = nil,
                    timeout: Duration) async throws -> ProcessResult {
        let directory = workingDirectory ?? URL(fileURLWithPath: NSHomeDirectory())
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ProcessError.launchFailed("The folder “\(directory.path)” does not exist.")
        }
        let arguments = [shell] + (loginShell ? ["-l"] : []) + ["-c", command]
        let state = RunState()
        let seconds = max(1, Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessResult, Error>) in
                state.setContinuation(continuation)
                let spawned: SpawnedProcess
                do {
                    spawned = try SpawnedProcess.spawn(arguments: arguments, environment: environment(),
                                                       directory: directory.path)
                } catch {
                    state.fail(error)
                    return
                }
                state.setProcessGroup(spawned.pid)

                let readers = DispatchGroup()
                for (fd, isOut) in [(spawned.stdout, true), (spawned.stderr, false)] {
                    readers.enter()
                    Thread.detachNewThread {
                        readAll(fd) { state.append($0, stdout: isOut) }
                        close(fd)
                        readers.leave()
                    }
                }
                Thread.detachNewThread {
                    if let input { writeAll(Data(input.utf8), to: spawned.stdin) }
                    close(spawned.stdin)
                }
                Thread.detachNewThread {
                    let status = waitForExit(spawned.pid)
                    _ = readers.wait(timeout: .now() + Self.outputGracePeriod)
                    state.finish(exitCode: status)
                }
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

/// A child started with posix_spawn in its own process group, with pipes
/// for its standard streams. Only the three pipes are inherited.
struct SpawnedProcess {
    let pid: pid_t
    let stdin: Int32
    let stdout: Int32
    let stderr: Int32

    static func spawn(arguments: [String], environment: [String: String], directory: String) throws -> SpawnedProcess {
        var input: [Int32] = [0, 0], output: [Int32] = [0, 0], errors: [Int32] = [0, 0]
        guard pipe(&input) == 0, pipe(&output) == 0, pipe(&errors) == 0 else {
            throw ProcessError.launchFailed(String(cString: strerror(errno)))
        }
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_adddup2(&actions, input[0], 0)
        posix_spawn_file_actions_adddup2(&actions, output[1], 1)
        posix_spawn_file_actions_adddup2(&actions, errors[1], 2)
        posix_spawn_file_actions_addchdir(&actions, directory)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // New process group (killable as a whole); close every other inherited
        // descriptor; start with no blocked signals and default handling
        // (the spawning thread may block signals, and the app ignores SIGPIPE).
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT
                                                    | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK))
        posix_spawnattr_setpgroup(&attributes, 0)
        var noSignals = sigset_t()
        sigemptyset(&noSignals)
        posix_spawnattr_setsigmask(&attributes, &noSignals)
        var defaults = sigset_t()
        sigemptyset(&defaults)
        for signal in [SIGPIPE, SIGTERM, SIGINT, SIGHUP, SIGQUIT] { sigaddset(&defaults, signal) }
        posix_spawnattr_setsigdefault(&attributes, &defaults)

        let argv = arguments.map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }

        var pid: pid_t = 0
        let result = posix_spawn(&pid, arguments[0], &actions, &attributes, argv, envp)
        close(input[0]); close(output[1]); close(errors[1])
        guard result == 0 else {
            close(input[1]); close(output[0]); close(errors[0])
            throw ProcessError.launchFailed(String(cString: strerror(result)))
        }
        return SpawnedProcess(pid: pid, stdin: input[1], stdout: output[0], stderr: errors[0])
    }
}

/// Reads until end of file, handing over each chunk as it arrives.
private func readAll(_ fd: Int32, chunk: (Data) -> Void) {
    var buffer = [UInt8](repeating: 0, count: 65536)
    while true {
        let count = read(fd, &buffer, buffer.count)
        if count > 0 {
            chunk(Data(buffer[0..<count]))
        } else if count < 0 && errno == EINTR {
            continue
        } else {
            return
        }
    }
}

private func writeAll(_ data: Data, to fd: Int32) {
    data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
        guard var pointer = bytes.baseAddress else { return }
        var remaining = bytes.count
        while remaining > 0 {
            let written = write(fd, pointer, remaining)
            if written < 0 {
                if errno == EINTR { continue }
                return  // EPIPE: the command stopped reading
            }
            pointer += written
            remaining -= written
        }
    }
}

/// Waits for the process and returns its exit status (128 + signal number
/// when it was killed by a signal, like shells report it).
private func waitForExit(_ pid: pid_t) -> Int32 {
    var status: Int32 = 0
    while waitpid(pid, &status, 0) < 0 {
        if errno != EINTR { return -1 }
    }
    let signal = status & 0x7f
    return signal == 0 ? (status >> 8) & 0xff : 128 + signal
}

/// Shared state between the reader threads, the exit waiter, the timeout
/// and cancellation. The continuation is resumed exactly once.
private final class RunState: @unchecked Sendable {
    // An unfair lock donates priority, so the main thread starting a run
    // doesn't wait on a lower-priority reader thread holding it.
    private let lock = OSAllocatedUnfairLock()
    private var continuation: CheckedContinuation<ProcessResult, Error>?
    private var processGroup: pid_t?
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

    func setProcessGroup(_ pid: pid_t) {
        lock.lock()
        processGroup = pid
        let alreadyDone = done
        lock.unlock()
        if alreadyDone { Self.stop(group: pid) }
    }

    func append(_ data: Data, stdout isOut: Bool) {
        lock.lock()
        if isOut { stdout.append(data) } else { stderr.append(data) }
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
        let group = processGroup
        lock.unlock()
        if let group { Self.stop(group: group) }
        c.resume(throwing: error)
    }

    /// SIGTERM to the whole process group, SIGKILL to what is left later.
    private static func stop(group: pid_t) {
        killpg(group, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + ProcessRunner.killGracePeriod) {
            killpg(group, SIGKILL)
        }
    }
}
