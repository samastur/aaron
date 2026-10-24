import Foundation
import Testing
@testable import AaronAI

struct ReviewSessionTests {
    let text = "Teh cat sat on teh mat. It was happy."

    func raw(_ original: String, prefix: String? = nil, replacement: String? = "X",
             message: String = "m") -> RawSuggestion {
        RawSuggestion(original: original, prefix: prefix, suffix: nil,
                      replacement: replacement, message: message, category: nil)
    }

    func session(_ raws: [RawSuggestion]) -> ReviewSession {
        var session = ReviewSession()
        session.add(raws, actionName: "Grammar", text: text)
        return session
    }

    @Test func addingResolvesRangesAndRecordsAction() {
        let s = session([raw("Teh", replacement: "The")])
        #expect(s.suggestions.count == 1)
        #expect(s.suggestions[0].range == NSRange(location: 0, length: 3))
        #expect(s.suggestions[0].status == .open)
        #expect(s.suggestions[0].actionName == "Grammar")
    }

    @Test func unresolvableSuggestionsAreKeptWithoutRange() {
        let s = session([raw("missing"), raw("at")])
        #expect(s.suggestions[0].status == .notFound)
        #expect(s.suggestions[0].range == nil)
        #expect(s.suggestions[1].status == .ambiguous)
    }

    @Test func acceptReturnsEditAndMarksAccepted() {
        var s = session([raw("Teh", replacement: "The")])
        let edit = s.accept(s.suggestions[0].id, in: text)
        #expect(edit == TextEdit(range: NSRange(location: 0, length: 3), replacement: "The"))
        #expect(s.suggestions[0].status == .accepted)
    }

    @Test func acceptingCommentDoesNothing() {
        var s = session([raw("Teh", replacement: nil)])
        #expect(s.accept(s.suggestions[0].id, in: text) == nil)
        #expect(s.suggestions[0].status == .open)
    }

    @Test func acceptWhenTextNoLongerMatchesMarksStale() {
        var s = session([raw("Teh", replacement: "The")])
        let changed = "Tex cat sat on teh mat. It was happy."
        #expect(s.accept(s.suggestions[0].id, in: changed) == nil)
        #expect(s.suggestions[0].status == .stale)
    }

    @Test func editBeforeSuggestionShiftsIt() {
        var s = session([raw("happy")])
        s.applyEdit(TextEdit(range: NSRange(location: 0, length: 3), replacement: "The big"))
        #expect(s.suggestions[0].range == NSRange(location: 35, length: 5))
    }

    @Test func editAfterSuggestionLeavesIt() {
        var s = session([raw("Teh", prefix: "")])
        s.applyEdit(TextEdit(range: NSRange(location: 10, length: 2), replacement: ""))
        #expect(s.suggestions[0].range == NSRange(location: 0, length: 3))
    }

    @Test func insertionAtSuggestionEndLeavesIt() {
        var s = session([raw("Teh", prefix: "")])
        s.applyEdit(TextEdit(range: NSRange(location: 3, length: 0), replacement: "!"))
        #expect(s.suggestions[0].range == NSRange(location: 0, length: 3))
        #expect(s.suggestions[0].status == .open)
    }

    @Test func insertionAtSuggestionStartShiftsIt() {
        var s = session([raw("happy")])
        s.applyEdit(TextEdit(range: NSRange(location: 31, length: 0), replacement: "very "))
        #expect(s.suggestions[0].range == NSRange(location: 36, length: 5))
    }

    @Test func overlappingEditMakesSuggestionStale() {
        var s = session([raw("happy")])
        s.applyEdit(TextEdit(range: NSRange(location: 33, length: 1), replacement: "P"))
        #expect(s.suggestions[0].status == .stale)
        #expect(s.suggestions[0].range == nil)
    }

    @Test func acceptingOneSuggestionShiftsLaterOnes() {
        var s = session([raw("Teh", prefix: "", replacement: "The very"), raw("happy")])
        let edit = s.accept(s.suggestions[0].id, in: text)!
        s.applyEdit(edit)
        #expect(s.suggestions[0].status == .accepted)
        #expect(s.suggestions[1].range == NSRange(location: 36, length: 5))
        #expect(s.suggestions[1].status == .open)
    }

    @Test func acceptingMarksOverlappingSuggestionStale() {
        var s = session([raw("cat sat"), raw("sat on")])
        let edit = s.accept(s.suggestions[0].id, in: text)!
        s.applyEdit(edit)
        #expect(s.suggestions[1].status == .stale)
    }

    @Test func dismissRemovesFromOpen() {
        var s = session([raw("happy")])
        s.dismiss(s.suggestions[0].id)
        #expect(s.suggestions[0].status == .dismissed)
        #expect(s.openSuggestions.isEmpty)
        #expect(s.highlights.isEmpty)
    }

    @Test func highlightsListOpenResolvedSuggestions() {
        let s = session([raw("happy"), raw("missing")])
        #expect(s.highlights.map(\.range) == [NSRange(location: 31, length: 5)])
    }

    @Test func suggestionAtLocationPrefersSmallestRange() {
        let s = session([raw("cat sat on"), raw("sat")])
        #expect(s.suggestion(at: 9)?.original == "sat")
        #expect(s.suggestion(at: 5)?.original == "cat sat on")
        #expect(s.suggestion(at: 30) == nil)
    }

    @Test func secondActionAppendsSuggestions() {
        var s = session([raw("happy")])
        s.add([raw("cat")], actionName: "Style", text: text)
        #expect(s.suggestions.map(\.actionName) == ["Grammar", "Style"])
    }

    @Test func clearRemovesEverything() {
        var s = session([raw("happy")])
        s.clear()
        #expect(s.suggestions.isEmpty)
    }

    @Test func nextOpenWrapsAround() {
        var s = session([raw("Teh", prefix: ""), raw("cat"), raw("happy")])
        s.dismiss(s.suggestions[1].id)
        #expect(s.nextOpen(after: s.suggestions[0].id)?.original == "happy")
        #expect(s.nextOpen(after: s.suggestions[2].id)?.original == "Teh")
        #expect(s.nextOpen(after: nil)?.original == "Teh")
    }
}
