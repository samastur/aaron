import XCTest

/// Launches Aaron with a temporary configuration that uses the fake tools
/// in `Fixtures`, so tests never call real AI services or blog tools.
@MainActor
class AaronUITestCase: XCTestCase {
    // setUp/tearDown are nonisolated in XCTest but always run on the main thread.
    nonisolated(unsafe) var app: XCUIApplication!
    nonisolated(unsafe) var workDirectory: URL!

    var fixtures: URL {
        Bundle(for: AaronUITestCase.self).resourceURL!.appendingPathComponent("Fixtures")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AaronUITests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // The next launch() terminates the running instance.
        try? FileManager.default.removeItem(at: workDirectory)
    }

    func script(_ name: String) -> String {
        "/bin/sh '\(fixtures.appendingPathComponent(name).path)'"
    }

    var supportDirectory: URL { workDirectory.appendingPathComponent("support") }

    func profileURL(_ name: String) -> URL {
        supportDirectory.appendingPathComponent("Profiles/\(name).json")
    }

    /// Writes the configuration as the profile "Default" (plus any extra
    /// profiles) and launches the app, optionally opening `document`.
    func launch(aiCommand: String? = nil, extraConfig: [String: Any] = [:], document: URL? = nil,
                profiles: [String: [String: Any]] = [:], defaultProfile: String? = nil) throws {
        var config: [String: Any] = [
            "aiProviders": [["id": "fake", "name": "Fake AI", "command": aiCommand ?? script("fake-ai.sh"), "timeoutSeconds": 20]],
            "aiActions": [["id": "check", "name": "Check Everything", "prompt": "Check the text.", "providerID": "fake"]],
            "previewRenderers": [["id": "external", "name": "Fake External", "command": script("fake-preview.sh")]],
            "pelican": ["tagsCommand": script("fake-tags.sh"),
                        "pluginsCommand": "printf 'pelican.plugins.simple_footnotes\\nmystery_plugin\\n'"],
        ]
        config.merge(extraConfig) { _, new in new }
        try FileManager.default.createDirectory(at: supportDirectory.appendingPathComponent("Profiles"),
                                                withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: config).write(to: profileURL("Default"))
        for (name, profile) in profiles {
            try JSONSerialization.data(withJSONObject: profile).write(to: profileURL(name))
        }
        if let defaultProfile {
            try JSONSerialization.data(withJSONObject: ["defaultProfile": defaultProfile])
                .write(to: supportDirectory.appendingPathComponent("profiles.json"))
        }

        app = XCUIApplication()
        app.launchEnvironment["AARON_SUPPORT_DIR"] = supportDirectory.path
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES", "-NSQuitAlwaysKeepsWindows", "NO"]
        if let document { app.launchArguments.append(document.path) }
        app.launch()
    }

    /// Opens a new untitled document window.
    func newDocument() {
        let editor = app.textViews["editor"]
        if !editor.waitForExistence(timeout: 3) {
            app.typeKey("n", modifierFlags: .command)
        }
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
    }

    func writeDocument(_ name: String, _ text: String) throws -> URL {
        let url = workDirectory.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10,
                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) did not appear", file: file, line: line)
    }

    func waitUntil(timeout: TimeInterval = 10, _ condition: @escaping () -> Bool,
                   file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate { _, _ in condition() }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed,
                       "condition not met", file: file, line: line)
    }
}
