import Foundation
import Testing
@testable import AaronPelican

struct TagCompletionTests {
    let tags = [
        TagInfo(name: "review", count: 25), TagInfo(name: "books", count: 16),
        TagInfo(name: "book", count: 14), TagInfo(name: "annual review", count: 8),
        TagInfo(name: "Rust", count: 2), TagInfo(name: "écriture", count: 1),
    ]

    func caret(after marker: String, in text: String) -> Int {
        let r = (text as NSString).range(of: marker)
        return NSMaxRange(r)
    }

    @Test func contextForTagBeingTyped() throws {
        let text = "Title: X\nTags: books, rev\n\nBody"
        let ctx = try #require(TagCompletion.context(in: text, caret: caret(after: "rev", in: text)))
        #expect(ctx.partial == "rev")
        #expect((text as NSString).substring(with: ctx.replaceRange) == "rev")
        #expect(ctx.existing == ["books"])
        #expect(!ctx.needsLeadingSpace)
    }

    @Test func contextForFirstTag() throws {
        let text = "Title: X\nTags: bo\n\nBody"
        let ctx = try #require(TagCompletion.context(in: text, caret: caret(after: "bo", in: text)))
        #expect(ctx.partial == "bo")
        #expect(ctx.existing.isEmpty)
    }

    @Test func contextForEmptyValue() throws {
        let text = "Title: X\nTags: \n\nBody"
        let ctx = try #require(TagCompletion.context(in: text, caret: caret(after: "Tags: ", in: text)))
        #expect(ctx.partial == "")
        #expect(ctx.replaceRange.length == 0)
    }

    @Test func contextRightAfterColonNeedsSpace() throws {
        let text = "Title: X\nTags:\n\nBody"
        let ctx = try #require(TagCompletion.context(in: text, caret: caret(after: "Tags:", in: text)))
        #expect(ctx.needsLeadingSpace)
    }

    @Test func multiWordPartial() throws {
        let text = "Title: X\nTags: a, annual re"
        let ctx = try #require(TagCompletion.context(in: text, caret: (text as NSString).length))
        #expect(ctx.partial == "annual re")
        #expect(ctx.existing == ["a"])
    }

    @Test func caretMidTokenUsesTextBeforeCaret() throws {
        let text = "Title: X\nTags: books, review, rust"
        let ctx = try #require(TagCompletion.context(in: text, caret: caret(after: "rev", in: text)))
        #expect(ctx.partial == "rev")
        #expect(ctx.existing == ["books", "rust"])
    }

    @Test func noContextOutsideTagsLine() {
        let text = "Title: X\nTags: a\n\nBody tags"
        #expect(TagCompletion.context(in: text, caret: caret(after: "Title: X", in: text)) == nil)
        #expect(TagCompletion.context(in: text, caret: (text as NSString).length) == nil)
        #expect(TagCompletion.context(in: text, caret: caret(after: "Ta", in: text)) == nil)
    }

    @Test func noContextWithoutMetadata() {
        #expect(TagCompletion.context(in: "Tags", caret: 4) == nil)
    }

    @Test func worksWithYAMLTagsField() throws {
        let text = "---\ntags: bo\n---\n"
        let ctx = try #require(TagCompletion.context(in: text, caret: caret(after: "bo", in: text)))
        #expect(ctx.partial == "bo")
    }

    @Test func candidatesPreferPrefixThenCount() {
        #expect(TagCompletion.candidates(for: "bo", in: tags, excluding: []) == ["books", "book"])
    }

    @Test func candidatesIncludeWordAndSubstringMatchesAfterPrefix() {
        #expect(TagCompletion.candidates(for: "rev", in: tags, excluding: []) == ["review", "annual review"])
        #expect(TagCompletion.candidates(for: "ook", in: tags, excluding: []) == ["books", "book"])
    }

    @Test func candidatesIgnoreCaseAndDiacritics() {
        #expect(TagCompletion.candidates(for: "ru", in: tags, excluding: []) == ["Rust"])
        #expect(TagCompletion.candidates(for: "ecr", in: tags, excluding: []) == ["écriture"])
    }

    @Test func candidatesExcludeTagsAlreadyPresent() {
        #expect(TagCompletion.candidates(for: "bo", in: tags, excluding: ["Books"]) == ["book"])
    }

    @Test func emptyPartialListsAllByCount() {
        #expect(TagCompletion.candidates(for: "", in: tags, excluding: []).prefix(3) == ["review", "books", "book"])
    }
}
