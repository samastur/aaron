import Foundation
import Testing
@testable import AaronAI

struct ResponseExtractorTests {
    let payload = #"{"suggestions":[{"original":"teh","prefix":"in ","suffix":" end","replacement":"the","message":"Typo.","category":"spelling"}]}"#

    @Test func parsesPlainJSON() throws {
        let suggestions = try ResponseExtractor.suggestions(from: payload)
        #expect(suggestions == [RawSuggestion(original: "teh", prefix: "in ", suffix: " end",
                                              replacement: "the", message: "Typo.", category: "spelling")])
    }

    @Test func parsesJSONInsideMarkdownFence() throws {
        let output = "Here you go:\n```json\n\(payload)\n```\nHope it helps."
        #expect(try ResponseExtractor.suggestions(from: output).count == 1)
    }

    @Test func parsesJSONSurroundedByProse() throws {
        let output = "Sure! \(payload) Let me know."
        #expect(try ResponseExtractor.suggestions(from: output).count == 1)
    }

    @Test func parsesClaudeJSONOutputWrapper() throws {
        let wrapper: [String: Any] = ["type": "result", "is_error": false, "result": "```json\n\(payload)\n```"]
        let data = try JSONSerialization.data(withJSONObject: wrapper)
        #expect(try ResponseExtractor.suggestions(from: String(decoding: data, as: UTF8.self)).count == 1)
    }

    @Test func acceptsBareArrayOfSuggestions() throws {
        let output = #"[{"original":"a","message":"m"}]"#
        #expect(try ResponseExtractor.suggestions(from: output) == [
            RawSuggestion(original: "a", prefix: nil, suffix: nil, replacement: nil, message: "m", category: nil),
        ])
    }

    @Test func nullReplacementMeansComment() throws {
        let output = #"{"suggestions":[{"original":"a","replacement":null,"message":"m"}]}"#
        #expect(try ResponseExtractor.suggestions(from: output).first?.replacement == nil)
    }

    @Test func missingMessageBecomesEmpty() throws {
        let output = #"{"suggestions":[{"original":"a","replacement":"b"}]}"#
        #expect(try ResponseExtractor.suggestions(from: output).first?.message == "")
    }

    @Test func emptySuggestionListIsValid() throws {
        #expect(try ResponseExtractor.suggestions(from: #"{"suggestions": []}"#).isEmpty)
    }

    @Test func braceInsideStringDoesNotConfuseExtraction() throws {
        let output = #"Note: {"suggestions":[{"original":"a } b","message":"has { brace"}]} trailing }"#
        #expect(try ResponseExtractor.suggestions(from: output).first?.original == "a } b")
    }

    @Test func outputWithoutJSONThrows() {
        #expect(throws: ResponseExtractor.ExtractionError.noSuggestions) {
            try ResponseExtractor.suggestions(from: "I could not find any problems.")
        }
    }

    @Test func skipsUnrelatedJSONObjects() throws {
        let output = #"{"note":"thinking"} then \#(payload)"#
        #expect(try ResponseExtractor.suggestions(from: output).count == 1)
    }
}
