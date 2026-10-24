import Foundation
import Testing
@testable import AaronCore

struct ProcessRunnerTests {
    let runner = ProcessRunner(loginShell: false)

    @Test func capturesStandardOutput() async throws {
        let result = try await runner.run("echo hello", timeout: .seconds(10))
        #expect(result.stdout == "hello\n")
        #expect(result.exitCode == 0)
    }

    @Test func passesStandardInput() async throws {
        let result = try await runner.run("tr a-z A-Z", input: "šum and text", timeout: .seconds(10))
        #expect(result.stdout == "šUM AND TEXT")
    }

    @Test func nonZeroExitThrowsWithStandardError() async throws {
        await #expect(throws: ProcessError.failed(exitCode: 3, stderr: "oops")) {
            try await runner.run("echo oops >&2; exit 3", timeout: .seconds(10))
        }
    }

    @Test func timesOut() async throws {
        let start = Date()
        await #expect(throws: ProcessError.timedOut) {
            try await runner.run("sleep 5", timeout: .milliseconds(300))
        }
        #expect(Date().timeIntervalSince(start) < 3)
    }

    @Test func cancellationStopsTheProcess() async throws {
        let start = Date()
        let task = Task { try await runner.run("sleep 5", timeout: .seconds(10)) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(Date().timeIntervalSince(start) < 3)
    }

    @Test func runsInWorkingDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        let result = try await runner.run("pwd -P", workingDirectory: dir, timeout: .seconds(10))
        let reported = URL(fileURLWithPath: result.stdout.trimmingCharacters(in: .newlines))
        #expect(reported.resolvingSymlinksInPath() == dir.resolvingSymlinksInPath())
    }

    @Test func runsInHomeDirectoryByDefault() async throws {
        let result = try await runner.run("pwd -P", timeout: .seconds(10))
        let reported = URL(fileURLWithPath: result.stdout.trimmingCharacters(in: .newlines))
        #expect(reported.resolvingSymlinksInPath() == URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath())
    }

    @Test func pathIncludesCommonToolDirectories() async throws {
        let result = try await runner.run("echo $PATH", timeout: .seconds(10))
        #expect(result.stdout.contains("/opt/homebrew/bin"))
        #expect(result.stdout.contains("/.local/bin"))
    }

    @Test func handlesLargeInputAndOutput() async throws {
        let big = String(repeating: "abcdefghij\n", count: 200_000)
        let result = try await runner.run("cat", input: big, timeout: .seconds(20))
        #expect(result.stdout.count == big.count)
    }

    @Test func missingCommandFails() async throws {
        await #expect(throws: ProcessError.self) {
            try await runner.run("definitely-not-a-command-xyz", timeout: .seconds(10))
        }
    }

    @Test func loginShellRuns() async throws {
        let result = try await ProcessRunner().run("echo ok", timeout: .seconds(20))
        #expect(result.stdout.hasSuffix("ok\n"))
    }
}
