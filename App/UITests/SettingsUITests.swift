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

        let configURL = profileURL("Default")
        waitUntil {
            (try? String(contentsOf: configURL, encoding: .utf8))?.contains("Tone check") == true
        }
    }

    func openSettings() -> XCUIElement {
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows["com_apple_SwiftUI_Settings_window"]
        waitFor(settings)
        return settings
    }

    func fileText(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }

    func testAddRenameAndSetDefaultProfile() throws {
        try launch(document: try writeDocument("s.md", "Text"))
        waitFor(app.textViews["editor"])
        let settings = openSettings()
        settings.toolbars.buttons["Profiles"].click()
        settings.buttons["addProfile"].click()
        let name = settings.textFields["profileName"]
        waitUntil { name.value as? String == "Default copy" }
        name.doubleClick()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Blog\r")
        waitUntil { FileManager.default.fileExists(atPath: self.profileURL("Blog").path) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: profileURL("Default copy").path))
        settings.buttons["setDefaultProfile"].click()
        let profilesJSON = supportDirectory.appendingPathComponent("profiles.json")
        waitUntil { self.fileText(profilesJSON).contains("Blog") }
        screenshot("settings-profiles")
    }

    func testSettingsEditTheSelectedProfileOnly() throws {
        try launch(document: try writeDocument("s.md", "Text"), profiles: ["Blog": [:]])
        waitFor(app.textViews["editor"])
        let settings = openSettings()
        settings.toolbars.buttons["General"].click()
        let picker = settings.popUpButtons["settingsProfile"]
        waitFor(picker)
        picker.click()
        settings.menuItems["Blog"].click()
        let size = settings.textFields["fontSize"]
        size.doubleClick()
        size.typeKey("a", modifierFlags: .command)
        size.typeText("30\t")
        waitUntil { self.fileText(self.profileURL("Blog")).contains("30") }
        XCTAssertFalse(fileText(profileURL("Default")).contains("\"fontSize\" : 30"))
    }
}
