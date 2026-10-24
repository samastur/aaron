import XCTest

final class PelicanUITests: AaronUITestCase {
    let post = "Title: A post\nDate: 2026-10-24 10:00\nTags: books\n\nSome text.\n"

    func testPelicanPostIsDetectedAndTagsLoad() throws {
        try launch(document: try writeDocument("post.md", post))
        waitFor(app.textViews["editor"])
        waitFor(app.staticTexts["3 tags"])
        XCTAssertEqual(app.staticTexts["documentMode"].value as? String, "Pelican")
        screenshot("pelican")
    }

    func testTagCompletionOffersMatchingTags() throws {
        try launch(document: try writeDocument("tags.md", post))
        let editor = app.textViews["editor"]
        waitFor(app.staticTexts["3 tags"])
        // Put the caret at the end of the Tags line: click, go to line 3's end.
        editor.click()
        editor.typeKey(.upArrow, modifierFlags: .command)
        editor.typeKey(.downArrow, modifierFlags: [])
        editor.typeKey(.downArrow, modifierFlags: [])
        editor.typeKey(.rightArrow, modifierFlags: .command)
        editor.typeText(", re")
        // The completion list (not exposed to accessibility) opens by itself
        // with the best match filled in; Return accepts it.
        sleep(1)
        screenshot("tag-completion")
        editor.typeKey(.return, modifierFlags: [])
        waitUntil { (editor.value as? String)?.contains("Tags: books, review") == true }
    }

    func testNewPelicanPostUsesTemplate() throws {
        try launch(document: try writeDocument("any.md", "x"))
        waitFor(app.textViews["editor"])
        app.typeKey("n", modifierFlags: [.command, .option])
        let newEditor = app.windows.firstMatch.textViews["editor"]
        waitUntil { (newEditor.value as? String)?.hasPrefix("Title: \nDate: 20") == true }
        XCTAssertTrue((newEditor.value as? String)?.contains("Status: draft") == true)
    }
}
