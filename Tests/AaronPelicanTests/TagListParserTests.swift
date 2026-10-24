import Testing
@testable import AaronPelican

struct TagListParserTests {
    @Test func parsesListTagsJSON() throws {
        let json = #"{"content": "/x", "posts": 3, "tags": [{"name": "review", "slug": "review", "count": 25, "variants": []}, {"name": "annual review", "count": 8}]}"#
        #expect(try TagListParser.parse(json) == [TagInfo(name: "review", count: 25), TagInfo(name: "annual review", count: 8)])
    }

    @Test func parsesJSONArrayOfStrings() throws {
        #expect(try TagListParser.parse(#"["a", "b"]"#) == [TagInfo(name: "a", count: 0), TagInfo(name: "b", count: 0)])
    }

    @Test func parsesJSONObjectWithStringTags() throws {
        #expect(try TagListParser.parse(#"{"tags": ["x"]}"#) == [TagInfo(name: "x", count: 0)])
    }

    @Test func parsesPlainLinesWithOptionalCounts() throws {
        let text = "25  review\nbooks\n  3 annual review  \n\n"
        #expect(try TagListParser.parse(text) == [
            TagInfo(name: "review", count: 25), TagInfo(name: "books", count: 0), TagInfo(name: "annual review", count: 3),
        ])
    }

    @Test func mergesDuplicatesIgnoringCase() throws {
        #expect(try TagListParser.parse("2 Swift\n5 swift") == [TagInfo(name: "Swift", count: 5)])
    }

    @Test func emptyOutputGivesNoTags() throws {
        #expect(try TagListParser.parse("  \n").isEmpty)
    }
}
