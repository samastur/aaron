import Foundation
import Testing
@testable import AaronCore

struct TextDiffTests {
    @Test func equalTextsHaveNoChange() {
        #expect(TextDiff.change(from: "same", to: "same") == nil)
    }

    @Test func insertionInTheMiddle() {
        let change = TextDiff.change(from: "one three", to: "one two three")
        #expect(change == TextDiff.Change(range: NSRange(location: 5, length: 0), replacement: "wo t"))
    }

    @Test func deletionAtTheEnd() {
        let change = TextDiff.change(from: "keep this", to: "keep")
        #expect(change == TextDiff.Change(range: NSRange(location: 4, length: 5), replacement: ""))
    }

    @Test func rangesCountUTF16() {
        let change = TextDiff.change(from: "👋 čaj", to: "👋 kava")
        #expect(change == TextDiff.Change(range: NSRange(location: 3, length: 3), replacement: "kava"))
    }

    @Test func repeatedCharactersDontOverlap() {
        // Prefix and suffix must not both claim the same "a".
        let change = TextDiff.change(from: "aa", to: "aaa")
        #expect(change == TextDiff.Change(range: NSRange(location: 2, length: 0), replacement: "a"))
    }

    @Test func selectionFollowsTheChange() {
        let change = TextDiff.Change(range: NSRange(location: 10, length: 5), replacement: "abc")
        #expect(change.adjust(NSRange(location: 2, length: 3)) == NSRange(location: 2, length: 3))
        #expect(change.adjust(NSRange(location: 20, length: 1)) == NSRange(location: 18, length: 1))
        #expect(change.adjust(NSRange(location: 12, length: 0)) == NSRange(location: 13, length: 0))
        #expect(change.adjust(NSRange(location: 8, length: 10)) == NSRange(location: 8, length: 8))
    }
}
