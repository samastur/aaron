import Foundation
import Testing
@testable import AaronAI

struct TextEditTests {
    @Test func insertionFromStorageEdit() {
        // "abc" -> "abXc": edited range is the new text, delta +1
        let edit = TextEdit(storageEditedRange: NSRange(location: 2, length: 1), changeInLength: 1, newText: "abXc")
        #expect(edit == TextEdit(range: NSRange(location: 2, length: 0), replacement: "X"))
    }

    @Test func deletionFromStorageEdit() {
        // "abcd" -> "ad": edited range is empty at 1, delta -2
        let edit = TextEdit(storageEditedRange: NSRange(location: 1, length: 0), changeInLength: -2, newText: "ad")
        #expect(edit == TextEdit(range: NSRange(location: 1, length: 2), replacement: ""))
    }

    @Test func replacementFromStorageEdit() {
        // "a cat b" -> "a dog b"
        let edit = TextEdit(storageEditedRange: NSRange(location: 2, length: 3), changeInLength: 0, newText: "a dog b")
        #expect(edit == TextEdit(range: NSRange(location: 2, length: 3), replacement: "dog"))
    }
}
