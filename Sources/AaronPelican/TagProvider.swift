import AaronCore
import Foundation

/// Runs the configured tag command and caches its result per command and
/// working directory.
public actor TagProvider {
    private let runner: ProcessRunner
    private var cache: [String: [TagInfo]] = [:]

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    public func tags(command: String, workingDirectory: URL?, timeout: Duration,
                     refresh: Bool = false) async throws -> [TagInfo] {
        guard !command.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let key = command + "\u{0}" + (workingDirectory?.path ?? "")
        if !refresh, let cached = cache[key] { return cached }
        let result = try await runner.run(command, workingDirectory: workingDirectory, timeout: timeout)
        let tags = try TagListParser.parse(result.stdout)
        cache[key] = tags
        return tags
    }
}
