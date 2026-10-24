import Testing
@testable import AaronCore

struct TextStatisticsTests {
    @Test func countsWordsAndCharacters() {
        let stats = TextStatistics(text: "Hello, wide world!")
        #expect(stats.words == 3)
        #expect(stats.characters == 18)
    }

    @Test func emptyText() {
        #expect(TextStatistics(text: "") == TextStatistics(words: 0, characters: 0))
    }

    @Test func excludesFrontMatter() {
        let stats = TextStatistics(text: "Title: Long title here\nTags: a\n\nTwo words")
        #expect(stats.words == 2)
        #expect(stats.characters == 9)
    }

    @Test func countsNonLatinWordsAndEmoji() {
        let stats = TextStatistics(text: "Čučka je 👍 tukaj")
        #expect(stats.words == 3)
        #expect(stats.characters == 16)
    }
}
