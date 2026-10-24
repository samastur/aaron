import Foundation
import Testing
import AaronCore
@testable import AaronAI

/// Calls the real AI command-line tools. Opt in with `AARON_LIVE_AI=1`;
/// requires `claude` and `codex` to be installed and logged in.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["AARON_LIVE_AI"] == "1"))
struct LiveProviderTests {
    let document = """
    Title: Test post
    Tags: test

    Docker is a virtual machine that makes deployment easier. I has been using it for years.
    """

    func check(provider id: String) async throws {
        let config = Configuration.default
        let provider = try #require(config.aiProviders.first { $0.id == id })
        let action = try #require(config.aiActions.first { $0.id == "grammar" })
        let raws = try await AIActionRunner().run(AIActionRequest(
            actionPrompt: action.prompt, providerCommand: provider.command,
            timeout: .seconds(provider.timeoutSeconds), document: document, selection: nil))
        var session = ReviewSession()
        session.add(raws, actionName: action.name, text: document)
        #expect(session.suggestions.contains { $0.original.contains("has") && $0.status == .open })
    }

    @Test func claudeFindsGrammarError() async throws { try await check(provider: "claude") }
    @Test func codexFindsGrammarError() async throws { try await check(provider: "codex") }
}
