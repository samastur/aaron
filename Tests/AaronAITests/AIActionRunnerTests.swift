import Foundation
import Testing
import AaronCore
@testable import AaronAI

struct AIActionRunnerTests {
    let runner = AIActionRunner(processRunner: ProcessRunner(loginShell: false))

    func request(command: String, document: String = "Hello wrld.") -> AIActionRequest {
        AIActionRequest(actionPrompt: "Fix spelling.", providerCommand: command,
                        timeout: .seconds(10), document: document, selection: nil)
    }

    @Test func sendsPromptOnStdinAndParsesSuggestions() async throws {
        let command = #"input=$(cat); grep -q 'Hello wrld' <<<"$input" && grep -q 'Fix spelling' <<<"$input" && echo '{"suggestions":[{"original":"wrld","replacement":"world","message":"Typo"}]}'"#
        let suggestions = try await runner.run(request(command: command))
        #expect(suggestions == [RawSuggestion(original: "wrld", prefix: nil, suffix: nil,
                                              replacement: "world", message: "Typo", category: nil)])
    }

    @Test func unparseableOutputThrowsInvalidResponse() async throws {
        await #expect(throws: AIActionError.invalidResponse("Sorry, I can't.")) {
            try await runner.run(request(command: "cat >/dev/null; echo \"Sorry, I can't.\""))
        }
    }

    @Test func providerFailureIsReported() async throws {
        await #expect(throws: ProcessError.failed(exitCode: 1, stderr: "not logged in")) {
            try await runner.run(request(command: "cat >/dev/null; echo 'not logged in' >&2; exit 1"))
        }
    }

    @Test func emptyCommandIsRejected() async throws {
        await #expect(throws: AIActionError.noCommand) {
            try await runner.run(request(command: " "))
        }
    }

    @Test func longInvalidOutputIsTruncatedInError() async throws {
        do {
            _ = try await runner.run(request(command: "cat >/dev/null; printf 'x%.0s' $(seq 1 3000)"))
            Issue.record("expected an error")
        } catch AIActionError.invalidResponse(let excerpt) {
            #expect(excerpt.count <= 1001)
        }
    }
}
