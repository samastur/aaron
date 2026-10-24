import XCTest

final class EditorUITests: AaronUITestCase {
    func testOpensDocumentShowsEditorPreviewAndWordCount() throws {
        let doc = try writeDocument("hello.md", "# Hello\n\nThree little words.\n")
        try launch(document: doc)
        let editor = app.textViews["editor"]
        waitFor(editor)
        XCTAssertEqual(editor.value as? String, "# Hello\n\nThree little words.\n")
        waitFor(app.staticTexts["4 words"])
        waitFor(app.webViews.staticTexts["Hello"])
        screenshot("editor-and-preview")
    }

    func testTypingUpdatesWordCountAndPreview() throws {
        let doc = try writeDocument("typing.md", "Start.\n")
        try launch(document: doc)
        let editor = app.textViews["editor"]
        waitFor(editor)
        editor.click()
        editor.typeKey(.downArrow, modifierFlags: .command)
        editor.typeText("\nA brand new sentence")
        waitFor(app.staticTexts["5 words"])
        waitFor(app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'brand new'")).firstMatch)
    }

    func testPreviewCanBeHiddenAndShown() throws {
        let doc = try writeDocument("toggle.md", "# Toggle\n")
        try launch(document: doc)
        waitFor(app.webViews.firstMatch)
        app.typeKey("p", modifierFlags: [.command, .option])
        waitUntil { !self.app.webViews.firstMatch.exists }
        app.typeKey("p", modifierFlags: [.command, .option])
        waitFor(app.webViews.staticTexts["Toggle"])
    }

    func testSwitchingToExternalRenderer() throws {
        let doc = try writeDocument("external.md", "# External\n")
        try launch(document: doc)
        let picker = app.popUpButtons["rendererPicker"]
        waitFor(picker)
        picker.click()
        app.menuItems["Fake External"].click()
        waitFor(app.webViews.staticTexts["External renderer"])
        screenshot("external-renderer")
    }
}
