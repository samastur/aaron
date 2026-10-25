import XCTest

final class ProfileUITests: AaronUITestCase {
    let post = "Title: A post\nDate: 2026-10-24 10:00\nTags: books\n\nSome text.\n"

    /// Default has the fake external renderer for Pelican posts; Plain
    /// never treats documents as Pelican posts and has no renderers.
    func launchWithTwoProfiles() throws {
        try launch(extraConfig: ["defaultRenderer": ["pelican": "external"]],
                   document: try writeDocument("post.md", post),
                   profiles: ["Plain": ["previewRenderers": [], "pelican": ["detection": "never"]]])
        waitFor(app.textViews["editor"])
    }

    func testSwitchingProfileFromViewMenu() throws {
        try launchWithTwoProfiles()
        let status = app.menuButtons["statusProfile"]
        waitFor(status)
        XCTAssertEqual(app.staticTexts["documentMode"].value as? String, "Pelican")
        XCTAssertEqual(status.title, "Default")
        let view = app.menuBars.menuBarItems["View"]
        view.click()
        view.menuItems["Profile"].click()
        view.menuItems["Profile"].menuItems["Plain"].click()
        waitUntil { status.title == "Plain" }
        waitUntil { self.app.staticTexts["documentMode"].value as? String == "Markdown" }
        let picker = app.popUpButtons["rendererPicker"]
        picker.click()
        XCTAssertFalse(app.menuItems["Fake External"].exists)
        app.typeKey(.escape, modifierFlags: [])
        screenshot("profile-plain")
    }

    func testSwitchingProfileFromStatusBar() throws {
        try launchWithTwoProfiles()
        let status = app.menuButtons["statusProfile"]
        waitFor(status)
        status.click()
        app.menuItems["Plain"].click()
        waitUntil { self.app.staticTexts["documentMode"].value as? String == "Markdown" }
        status.click()
        app.menuItems["Default"].click()
        waitUntil { self.app.staticTexts["documentMode"].value as? String == "Pelican" }
    }
}
