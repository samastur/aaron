import Testing
@testable import AaronAI

struct PromptBuilderTests {
    @Test func includesActionInstructionsFormatAndDocument() {
        let prompt = PromptBuilder.build(actionPrompt: "Fix grammar.", document: "Hello wrld.", selection: nil)
        #expect(prompt.contains("Fix grammar."))
        #expect(prompt.contains(#""suggestions""#))
        #expect(prompt.contains("<document>\nHello wrld.\n</document>"))
        #expect(!prompt.contains("<selection>"))
    }

    @Test func instructionsComeBeforeTheDocument() throws {
        let prompt = PromptBuilder.build(actionPrompt: "Fix grammar.", document: "Doc", selection: nil)
        let task = try #require(prompt.range(of: "Fix grammar."))
        let doc = try #require(prompt.range(of: "<document>"))
        #expect(task.lowerBound < doc.lowerBound)
    }

    @Test func selectionAddsFocusSection() {
        let prompt = PromptBuilder.build(actionPrompt: "Check.", document: "A b c.", selection: "b")
        #expect(prompt.contains("<selection>\nb\n</selection>"))
        #expect(prompt.contains("only"))
    }

    @Test func explainsQuotingRules() {
        let prompt = PromptBuilder.build(actionPrompt: "x", document: "y", selection: nil)
        for field in ["original", "prefix", "suffix", "replacement", "message", "category"] {
            #expect(prompt.contains(#""\#(field)""#))
        }
    }
}
