import Foundation
import Testing
@testable import AaronCore

struct MarkdownHighlighterTests {
    func runs(_ text: String, _ kind: StyleRun.Kind) -> [String] {
        let ns = text as NSString
        return MarkdownHighlighter.runs(in: text).filter { $0.kind == kind }.map { ns.substring(with: $0.range) }
    }

    @Test func headings() {
        let text = "# Title\n\nText\n### Sub head\n#nospace"
        #expect(runs(text, .heading) == ["# Title", "### Sub head"])
    }

    @Test func emphasisAndStrong() {
        let text = "Some *em* and **strong** and _also_ and __this__."
        #expect(runs(text, .emphasis) == ["*em*", "_also_"])
        #expect(runs(text, .strong) == ["**strong**", "__this__"])
    }

    @Test func underscoresInsideWordsAreNotEmphasis() {
        #expect(runs("snake_case_name here", .emphasis).isEmpty)
    }

    @Test func inlineCode() {
        #expect(runs("Use `let x = 1` now", .code) == ["`let x = 1`"])
    }

    @Test func fencedCodeBlocksAreNotInlineStyled() {
        let text = "Before\n```swift\nlet *x* = 1\n```\nAfter *em*"
        #expect(runs(text, .codeBlock) == ["```swift\nlet *x* = 1\n```"])
        #expect(runs(text, .emphasis) == ["*em*"])
    }

    @Test func unterminatedFenceRunsToEnd() {
        #expect(runs("A\n```\ncode", .codeBlock) == ["```\ncode"])
    }

    @Test func links() {
        let text = "See [the docs](https://example.com \"t\") and <https://x.org>."
        #expect(runs(text, .linkText) == ["the docs"])
        #expect(runs(text, .linkURL) == ["https://example.com", "https://x.org"])
    }

    @Test func blockQuotesAndListMarkers() {
        let text = "> quoted line\n- item\n  * nested\n12. numbered\nnot-a-list"
        #expect(runs(text, .quote) == ["> quoted line"])
        #expect(runs(text, .listMarker) == ["-", "*", "12."])
    }

    @Test func metadataBlock() {
        let text = "Title: Hello\nTags: a, b\n\n# Body"
        #expect(runs(text, .metadataKey) == ["Title", "Tags"])
        #expect(runs(text, .metadataValue) == ["Hello", "a, b"])
        #expect(runs(text, .heading) == ["# Body"])
    }

    @Test func plainTextHasNoRuns() {
        #expect(MarkdownHighlighter.runs(in: "Just words here.").isEmpty)
    }
}
