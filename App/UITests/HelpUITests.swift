import XCTest

final class HelpUITests: AaronUITestCase {
    func testMarkdownHelpForPlainMarkdown() throws {
        try launch(document: try writeDocument("plain.md", "# Plain\n"))
        waitFor(app.textViews["editor"])
        app.typeKey("m", modifierFlags: [.command, .shift])
        let help = app.windows["Markdown Help"]
        waitFor(help)
        waitFor(help.webViews.staticTexts["Markdown help"])
        XCTAssertFalse(help.webViews.staticTexts["Plugins"].exists)
        screenshot("markdown-help")
    }

    func testMarkdownHelpForPelicanPostListsPlugins() throws {
        try launch(document: try writeDocument("post.md", "Title: A post\nDate: 2026-10-24\n\nText.\n"))
        waitFor(app.textViews["editor"])
        let helpMenu = app.menuBars.menuBarItems["Help"]
        helpMenu.click()
        helpMenu.menuItems["Markdown Help"].click()
        let help = app.windows["Markdown Help"]
        waitFor(help)
        waitFor(help.webViews.staticTexts["Plugins"])
        XCTAssertTrue(help.webViews.staticTexts["simple_footnotes"].exists)
        XCTAssertTrue(help.webViews.staticTexts["mystery_plugin"].exists)
        screenshot("pelican-help")
    }
}
