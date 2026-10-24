import Foundation
import Testing
@testable import AaronCore

struct FrontMatterTests {
    let pelican = "Title: Hello world\nDate: 2026-01-02 10:00\nTags: a, b\n\nBody text.\n"

    @Test func parsesPelicanMetadata() throws {
        let fm = try #require(FrontMatter.parse(pelican))
        #expect(fm.style == .pelican)
        #expect(fm.fields.map(\.key) == ["Title", "Date", "Tags"])
        #expect(fm.value(for: "title") == "Hello world")
        #expect(fm.value(for: "Tags") == "a, b")
    }

    @Test func bodyStartsAfterBlankLine() throws {
        let fm = try #require(FrontMatter.parse(pelican))
        #expect((pelican as NSString).substring(from: fm.bodyStart) == "Body text.\n")
    }

    @Test func fieldRangesPointIntoText() throws {
        let fm = try #require(FrontMatter.parse(pelican))
        let tags = try #require(fm.field(named: "tags"))
        let ns = pelican as NSString
        #expect(ns.substring(with: tags.keyRange) == "Tags")
        #expect(ns.substring(with: tags.valueRange) == "a, b")
        #expect(ns.substring(with: tags.lineRange) == "Tags: a, b")
    }

    @Test func metadataOnlyDocument() throws {
        let fm = try #require(FrontMatter.parse("Title: Only"))
        #expect(fm.value(for: "Title") == "Only")
        #expect(fm.bodyStart == 11)
    }

    @Test func emptyValueIsAllowed() throws {
        let fm = try #require(FrontMatter.parse("Title: X\nTags:\n\nBody"))
        let tags = try #require(fm.field(named: "Tags"))
        #expect(tags.value == "")
        #expect(tags.valueRange == NSRange(location: 14, length: 0))
    }

    @Test func continuationLinesExtendValue() throws {
        let fm = try #require(FrontMatter.parse("Title: X\nSummary: first\n    second\n\nBody"))
        #expect(fm.value(for: "Summary") == "first second")
    }

    @Test func documentWithoutMetadata() {
        #expect(FrontMatter.parse("# Heading\n\nText") == nil)
        #expect(FrontMatter.parse("") == nil)
        #expect(FrontMatter.parse("\nTitle: late") == nil)
    }

    @Test func linkLikeFirstLineIsNotMetadata() {
        #expect(FrontMatter.parse("http://example.com is great\n") == nil)
    }

    @Test func parsesYAMLFrontMatter() throws {
        let text = "---\ntitle: Hello\ntags: [a, b]\n---\n\nBody"
        let fm = try #require(FrontMatter.parse(text))
        #expect(fm.style == .yaml)
        #expect(fm.value(for: "title") == "Hello")
        #expect((text as NSString).substring(from: fm.bodyStart) == "Body")
    }

    @Test func unterminatedYAMLIsNotFrontMatter() {
        #expect(FrontMatter.parse("---\ntitle: Hello\n\nBody") == nil)
    }

    @Test func handlesCRLFLineEndings() throws {
        let fm = try #require(FrontMatter.parse("Title: X\r\nTags: a\r\n\r\nBody"))
        #expect(fm.value(for: "Tags") == "a")
    }
}
