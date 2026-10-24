import XCTest

final class ReviewUITests: AaronUITestCase {
    let story = "# Story\n\nThe cat saw teh quick fox. It jumped over the dog.\n"

    func runCheck() {
        // Review ▸ Check Everything (⌥⌘1)
        app.typeKey("1", modifierFlags: [.command, .option])
    }

    func testRunningActionShowsSuggestionsAndAcceptChangesText() throws {
        try launch(document: try writeDocument("story.md", story))
        let editor = app.textViews["editor"]
        waitFor(editor)
        runCheck()
        waitFor(app.staticTexts["Spelling mistake."], timeout: 20)
        waitFor(app.staticTexts["Not found in text"])
        screenshot("suggestions")

        app.buttons["acceptSuggestion"].firstMatch.click()
        waitUntil { (editor.value as? String)?.contains("saw the quick") == true }
        screenshot("accepted")

        // Undo restores the text.
        editor.typeKey("z", modifierFlags: .command)
        waitUntil { (editor.value as? String)?.contains("saw teh quick") == true }
    }

    func testEditorIsReadOnlyWhileActionRunsAndCancelWorks() throws {
        try launch(aiCommand: script("slow-ai.sh"), document: try writeDocument("slow.md", story))
        let editor = app.textViews["editor"]
        waitFor(editor)
        runCheck()
        waitFor(app.buttons["cancelAction"])
        editor.click()
        editor.typeText("XYZ")
        XCTAssertFalse((editor.value as? String)?.contains("XYZ") ?? true)
        app.typeKey(".", modifierFlags: .command)
        waitUntil { !self.app.buttons["cancelAction"].exists }
        editor.typeText("XYZ")
        waitUntil { (editor.value as? String)?.contains("XYZ") == true }
    }

    func testFailingProviderShowsError() throws {
        try launch(aiCommand: script("failing-ai.sh"), document: try writeDocument("fail.md", story))
        waitFor(app.textViews["editor"])
        runCheck()
        waitFor(app.otherElements["aiError"].firstMatch, timeout: 20)
        screenshot("ai-error")
    }

    func testDismissAndKeyboardNavigation() throws {
        try launch(document: try writeDocument("nav.md", story))
        waitFor(app.textViews["editor"])
        runCheck()
        waitFor(app.staticTexts["Spelling mistake."], timeout: 20)
        // Next suggestion, then dismiss it with ⌥⌘⌫.
        app.typeKey("]", modifierFlags: [.command, .option])
        app.typeKey(.delete, modifierFlags: [.command, .option])
        waitUntil { !self.app.staticTexts["Consider a stronger verb."].exists }
        waitFor(app.staticTexts["reviewSummary"])
    }

    func testToolbarTogglesReviewPanel() throws {
        try launch(document: try writeDocument("panel.md", story))
        waitFor(app.textViews["editor"])
        app.typeKey("r", modifierFlags: [.command, .option])
        waitFor(app.staticTexts["No suggestions yet"])
        app.typeKey("r", modifierFlags: [.command, .option])
        waitUntil { !self.app.staticTexts["No suggestions yet"].exists }
    }
}
