import Foundation
import Testing
@testable import AaronCore

/// `|` marks the caret, `[` `]` the selection, in both the input and the
/// expected result.
private func run(_ marked: String, _ format: (String, NSRange) -> FormattingEdit) -> String {
    let (text, selection) = unmark(marked)
    let edit = format(text, selection)
    return mark(edit.applied(to: text), edit.selection)
}

private func unmark(_ marked: String) -> (String, NSRange) {
    let ns = marked as NSString
    let caret = ns.range(of: "|")
    if caret.location != NSNotFound {
        return (ns.replacingCharacters(in: caret, with: ""), NSRange(location: caret.location, length: 0))
    }
    let open = ns.range(of: "[[").location
    let text = marked.replacingOccurrences(of: "[[", with: "").replacingOccurrences(of: "]]", with: "")
    let close = ns.range(of: "]]").location - 2
    return (text, NSRange(location: open, length: close - open))
}

private func mark(_ text: String, _ selection: NSRange) -> String {
    let ns = text as NSString
    if selection.length == 0 { return ns.replacingCharacters(in: selection, with: "|") }
    return ns.replacingCharacters(in: selection, with: "[[" + ns.substring(with: selection) + "]]")
}

struct MarkdownFormattingTests {
    let bold = MarkdownFormatting.toggleBold
    let italic = MarkdownFormatting.toggleItalic
    let quote = MarkdownFormatting.toggleQuote

    @Test func boldWrapsAndUnwraps() {
        #expect(run("a [[word]] b", bold) == "a **[[word]]** b")
        #expect(run("a **[[word]]** b", bold) == "a [[word]] b")
        #expect(run("a [[**word**]] b", bold) == "a [[word]] b")
        #expect(run("a __[[word]]__ b", bold) == "a [[word]] b")
    }

    @Test func boldIgnoresSurroundingWhitespaceInSelection() {
        #expect(run("a[[ word ]]b", bold) == "a **[[word]]** b")
    }

    @Test func boldWithoutSelectionUsesWordOrInsertsPair() {
        #expect(run("a wo|rd b", bold) == "a **[[word]]** b")
        #expect(run("a | b", bold) == "a **|** b")
        #expect(run("a **|** b", bold) == "a | b")
    }

    @Test func italicWrapsAndUnwraps() {
        #expect(run("[[word]]", italic) == "*[[word]]*")
        #expect(run("*[[word]]*", italic) == "[[word]]")
        #expect(run("_[[word]]_", italic) == "[[word]]")
        #expect(run("[[*word*]]", italic) == "[[word]]")
    }

    @Test func boldAndItalicCombine() {
        #expect(run("**[[word]]**", italic) == "***[[word]]***")
        #expect(run("***[[word]]***", italic) == "**[[word]]**")
        #expect(run("***[[word]]***", bold) == "*[[word]]*")
        #expect(run("*[[word]]*", bold) == "***[[word]]***")
    }

    @Test func linkFromText() {
        let link = { MarkdownFormatting.insertLink(in: $0, selection: $1, clipboardURL: nil) }
        #expect(run("see [[the docs]] now", link) == "see [the docs](|) now")
        #expect(run("see | now", link) == "see [|]() now")
    }

    @Test func linkUsesClipboardURL() {
        let link = { MarkdownFormatting.insertLink(in: $0, selection: $1, clipboardURL: "https://example.com\n") }
        #expect(run("see [[the docs]] now", link) == "see [the docs](https://example.com)| now")
        #expect(run("see | now", link) == "see [|](https://example.com) now")
        let notURL = { MarkdownFormatting.insertLink(in: $0, selection: $1, clipboardURL: "just text") }
        #expect(run("[[docs]]", notURL) == "[docs](|)")
    }

    @Test func linkFromSelectedURL() {
        let link = { MarkdownFormatting.insertLink(in: $0, selection: $1, clipboardURL: "https://other.com") }
        #expect(run("at [[https://example.com/a]]", link) == "at [|](https://example.com/a)")
    }

    @Test func quoteAddsAndRemoves() {
        #expect(run("one\nt|wo\nthree", quote) == "one\n> t|wo\nthree")
        #expect(run("one\n> t|wo\nthree", quote) == "one\nt|wo\nthree")
        #expect(run("[[one\n\ntwo]]\n", quote) == "[[> one\n>\n> two]]\n")
        #expect(run("[[> one\n>\n> two]]\n", quote) == "[[one\n\ntwo]]\n")
    }

    @Test func quoteOfWholeLinesLeavesNextLineAlone() {
        #expect(run("[[one\n]]two", quote) == "[[> one]]\ntwo")
    }

    @Test func quoteOnEmptyLine() {
        #expect(run("a\n|\nb", quote) == "a\n> |\nb")
    }

    @Test func quoteOfPartlyQuotedLinesQuotesAll() {
        #expect(run("[[> one\ntwo]]", quote) == "[[> > one\n> two]]")
    }

    @Test func inlineHTMLIsInsertedAsIs() {
        let insert = { MarkdownFormatting.insertHTML("<kbd>⌘B</kbd>\n", in: $0, selection: $1) }
        #expect(run("Press | now", insert) == "Press <kbd>⌘B</kbd>| now")
        #expect(run("Press [[it]] now", insert) == "Press <kbd>⌘B</kbd>| now")
    }

    @Test func blockHTMLGetsEmptyLinesAround() {
        let insert = { MarkdownFormatting.insertHTML("<div>\nhi\n</div>", in: $0, selection: $1) }
        #expect(run("Text.|", insert) == "Text.\n\n<div>\nhi\n</div>\n|")
        #expect(run("Text.\n\n|\n\nMore", insert) == "Text.\n\n<div>\nhi\n</div>|\n\nMore")
        #expect(run("|More", insert) == "<div>\nhi\n</div>\n\n|More")
        #expect(run("|", insert) == "<div>\nhi\n</div>\n|")
    }
}
