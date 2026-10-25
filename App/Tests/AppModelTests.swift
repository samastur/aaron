import AaronCore
import AppKit
import XCTest
@testable import Aaron

@MainActor
final class AppModelTests: XCTestCase {
    nonisolated(unsafe) var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("AppModelTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    var store: ProfileStore { ProfileStore(directory: directory) }

    func writeProfile(_ name: String, _ text: String) throws {
        try FileManager.default.createDirectory(at: store.profilesDirectory, withIntermediateDirectories: true)
        try text.write(to: store.url(for: name), atomically: true, encoding: .utf8)
    }

    func waitForSave() async throws {
        try await Task.sleep(for: .milliseconds(700))
    }

    func testMissingFolderMigratesAndSavesChanges() async throws {
        try #"{"editor": {"fontSize": 21}}"#.write(to: directory.appendingPathComponent("config.json"),
                                                   atomically: true, encoding: .utf8)
        let model = AppModel(store: store)
        XCTAssertEqual(model.profileNames, ["Default"])
        XCTAssertEqual(model.defaultProfileName, "Default")
        XCTAssertEqual(model.configuration(for: "Default").editor.fontSize, 21)
        XCTAssertNil(model.configurationError)
        var changed = model.configuration(for: "Default")
        changed.editor.fontSize = 20
        model.setConfiguration(changed, for: "Default")
        try await waitForSave()
        XCTAssertEqual(try store.load("Default").editor.fontSize, 20)
    }

    func testUnreadableProfileIsReportedAndNeverOverwritten() async throws {
        let broken = "{ \"editor\": { broken"
        try writeProfile("Bad", broken)
        try writeProfile("Good", "{}")
        let model = AppModel(store: store)
        XCTAssertEqual(model.profileNames, ["Bad", "Good"])
        XCTAssertNotNil(model.configurationError)
        XCTAssertTrue(model.configurationError?.contains("Bad") == true)
        model.configurationError = nil  // the user dismissed the alert
        var bad = model.configuration(for: "Bad")
        bad.editor.fontSize = 22
        model.setConfiguration(bad, for: "Bad")
        var good = model.configuration(for: "Good")
        good.editor.fontSize = 23
        model.setConfiguration(good, for: "Good")
        try await waitForSave()
        XCTAssertEqual(try String(contentsOf: store.url(for: "Bad"), encoding: .utf8), broken)
        XCTAssertEqual(try store.load("Good").editor.fontSize, 23)
    }

    func testReloadAfterFixingResumesSaving() async throws {
        try writeProfile("Default", "{ broken")
        let model = AppModel(store: store)
        try writeProfile("Default", #"{"editor": {"fontSize": 17}}"#)
        model.reloadProfiles()
        XCTAssertNil(model.configurationError)
        XCTAssertEqual(model.configuration(for: "Default").editor.fontSize, 17)
        var config = model.configuration(for: "Default")
        config.editor.monospaced = true
        model.setConfiguration(config, for: "Default")
        try await waitForSave()
        XCTAssertTrue(try store.load("Default").editor.monospaced)
    }

    func testPendingChangesAreSavedWhenTheAppQuits() throws {
        let model = AppModel(store: store)
        var config = model.configuration(for: "Default")
        config.editor.fontSize = 19
        model.setConfiguration(config, for: "Default")
        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: NSApp)
        XCTAssertEqual(try store.load("Default").editor.fontSize, 19)
    }

    func testReloadDoesNotRewriteFiles() async throws {
        let text = #"{"editor": {"fontSize": 17}}"#
        try writeProfile("Default", text)
        let model = AppModel(store: store)
        model.reloadProfiles()
        try await waitForSave()
        XCTAssertEqual(try String(contentsOf: store.url(for: "Default"), encoding: .utf8), text)
    }

    func testSettingsConfigurationEditsTheSelectedProfile() async throws {
        try writeProfile("Blog", "{}")
        try writeProfile("Default", "{}")
        let model = AppModel(store: store)
        model.settingsProfileName = "Blog"
        model.settingsConfiguration.editor.fontSize = 30
        try await waitForSave()
        XCTAssertEqual(try store.load("Blog").editor.fontSize, 30)
        XCTAssertEqual(try store.load("Default").editor.fontSize, EditorSettings().fontSize)
    }

    func testRenamingDefaultKeepsItDefault() throws {
        try writeProfile("Default", "{}")
        try writeProfile("Plain", "{}")
        let model = AppModel(store: store)
        model.settingsProfileName = "Default"
        try model.renameProfile("Default", to: "Blog")
        XCTAssertEqual(model.profileNames, ["Blog", "Plain"])
        XCTAssertEqual(model.defaultProfileName, "Blog")
        XCTAssertEqual(model.settingsProfileName, "Blog")
        XCTAssertEqual(store.defaultProfileName(), "Blog")
    }

    func testRenameKeepsUnsavedChanges() throws {
        let model = AppModel(store: store)
        var config = model.configuration(for: "Default")
        config.editor.fontSize = 28
        model.setConfiguration(config, for: "Default")
        try model.renameProfile("Default", to: "Blog")
        model.saveIfPending()
        XCTAssertEqual(try store.load("Blog").editor.fontSize, 28)
    }

    func testInvalidRenameThrowsAndChangesNothing() throws {
        try writeProfile("Default", "{}")
        try writeProfile("Plain", "{}")
        let model = AppModel(store: store)
        XCTAssertThrowsError(try model.renameProfile("Default", to: "plain"))
        XCTAssertEqual(model.profileNames, ["Default", "Plain"])
    }

    func testAddProfileCopiesAndNamesUniquely() throws {
        let model = AppModel(store: store)
        var config = model.configuration(for: "Default")
        config.editor.fontSize = 11
        model.setConfiguration(config, for: "Default")
        XCTAssertEqual(try model.addProfile(copying: "Default"), "Default copy")
        XCTAssertEqual(try model.addProfile(copying: "Default"), "Default copy 2")
        XCTAssertEqual(model.profileNames, ["Default", "Default copy", "Default copy 2"])
        XCTAssertEqual(try store.load("Default copy").editor.fontSize, 11)
    }

    func testDeleteAndSetDefault() throws {
        try writeProfile("Default", "{}")
        try writeProfile("Plain", "{}")
        let model = AppModel(store: store)
        try model.setDefaultProfile("Plain")
        XCTAssertEqual(model.defaultProfileName, "Plain")
        XCTAssertThrowsError(try model.deleteProfile("Plain"))
        model.settingsProfileName = "Default"
        try model.deleteProfile("Default")
        XCTAssertEqual(model.profileNames, ["Plain"])
        XCTAssertEqual(model.settingsProfileName, "Plain")
    }

    func testImportProfile() throws {
        let source = directory.appendingPathComponent("blog.json")
        try #"{"pelican": {"tagsCommand": "tags"}}"#.write(to: source, atomically: true, encoding: .utf8)
        let model = AppModel(store: store)
        try model.importProfile(from: source, named: "Blog")
        XCTAssertEqual(model.profileNames, ["Blog", "Default"])
        XCTAssertEqual(model.configuration(for: "Blog").pelican.tagsCommand, "tags")
    }

    func testUnknownProfileFallsBackToDefault() throws {
        let model = AppModel(store: store)
        XCTAssertEqual(model.configuration(for: "Nope"), model.configuration(for: "Default"))
    }
}
