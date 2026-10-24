import XCTest

final class SettingsUITests: AaronUITestCase {
    func testAddingAnActionShowsItInTheReviewMenuAndSavesConfig() throws {
        try launch(document: try writeDocument("s.md", "Text"))
        waitFor(app.textViews["editor"])
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows.containing(.toolbarButton, identifier: "AI").firstMatch
        waitFor(app.toolbarButtons["AI"])
        app.toolbarButtons["AI"].click()
        settings.buttons["plus"].firstMatch.click()
        let name = settings.textFields["Name"].firstMatch
        waitFor(name)
        name.doubleClick()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Tone check")
        screenshot("settings-ai")
        app.typeKey("w", modifierFlags: .command)

        app.menuBars.menuBarItems["Review"].click()
        waitFor(app.menuItems["Tone check"])
        app.typeKey(.escape, modifierFlags: [])

        let configURL = workDirectory.appendingPathComponent("config.json")
        waitUntil {
            (try? String(contentsOf: configURL, encoding: .utf8))?.contains("Tone check") == true
        }
    }
}
