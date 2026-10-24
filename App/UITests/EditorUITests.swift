import XCTest

final class EditorUITests: AaronUITestCase {
    func testOpensDocumentShowsEditorPreviewAndWordCount() throws {
        let doc = try writeDocument("hello.md", "# Hello\n\nThree little words.\n")
        try launch(document: doc)
        waitFor(app.textViews["editor"])
        XCTAssertEqual(app.textViews["editor"].value as? String, "# Hello\n\nThree little words.\n")
        waitFor(app.staticTexts["4 words"])
        XCTAssertEqual(app.staticTexts["documentMode"].value as? String ?? app.staticTexts["documentMode"].label, "Markdown")
        waitFor(app.webViews.staticTexts["Hello"])
        screenshot("editor-and-preview")
    }
}
