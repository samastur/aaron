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

    var configURL: URL { directory.appendingPathComponent("config.json") }

    func waitForSave() async throws {
        try await Task.sleep(for: .milliseconds(700))
    }

    func testMissingFileStartsWithDefaultsAndSavesChanges() async throws {
        let model = AppModel(configurationURL: configURL)
        XCTAssertEqual(model.configuration, .default)
        XCTAssertNil(model.configurationError)
        model.configuration.editor.fontSize = 20
        try await waitForSave()
        XCTAssertEqual(try ConfigurationStore.load(from: configURL).editor.fontSize, 20)
    }

    func testUnreadableFileIsReportedAndNeverOverwritten() async throws {
        let broken = "{ \"editor\": { broken"
        try broken.write(to: configURL, atomically: true, encoding: .utf8)
        let model = AppModel(configurationURL: configURL)
        XCTAssertNotNil(model.configurationError)
        model.configurationError = nil  // the user dismissed the alert
        model.configuration.editor.fontSize = 22
        try await waitForSave()
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), broken)
    }

    func testReloadAfterFixingFileResumesSaving() async throws {
        try "{ broken".write(to: configURL, atomically: true, encoding: .utf8)
        let model = AppModel(configurationURL: configURL)
        try #"{"editor": {"fontSize": 17}}"#.write(to: configURL, atomically: true, encoding: .utf8)
        model.reloadConfiguration()
        XCTAssertNil(model.configurationError)
        XCTAssertEqual(model.configuration.editor.fontSize, 17)
        model.configuration.editor.monospaced = true
        try await waitForSave()
        XCTAssertTrue(try ConfigurationStore.load(from: configURL).editor.monospaced)
    }

    func testPendingChangesAreSavedWhenTheAppQuits() throws {
        let model = AppModel(configurationURL: configURL)
        model.configuration.editor.fontSize = 19
        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: NSApp)
        XCTAssertEqual(try ConfigurationStore.load(from: configURL).editor.fontSize, 19)
    }

    func testReloadDoesNotRewriteFile() async throws {
        let text = #"{"editor": {"fontSize": 17}}"#
        try text.write(to: configURL, atomically: true, encoding: .utf8)
        let model = AppModel(configurationURL: configURL)
        model.reloadConfiguration()
        try await waitForSave()
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), text)
    }
}
