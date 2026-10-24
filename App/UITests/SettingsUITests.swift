import XCTest

final class SettingsUITests: AaronUITestCase {
    func testAddingAnActionShowsItInTheReviewMenuAndSavesConfig() throws {
        try launch(document: try writeDocument("s.md", "Text"))
        waitFor(app.textViews["editor"])
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows["com_apple_SwiftUI_Settings_window"]
        waitFor(settings)
        settings.toolbars.buttons["AI"].click()
        settings.buttons["addItem"].click()
        let name = settings.textFields["itemName"]
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
