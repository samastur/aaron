import AaronCore
import AppKit
import XCTest
@testable import Aaron

@MainActor
final class SessionRestoreTests: XCTestCase {
    var app: AppModel!
    var models: [DocumentWindowModel] = []
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("session-\(UUID().uuidString)")

    override func setUp() async throws {
        app = AppModel(store: ProfileStore(directory: folder.appendingPathComponent("support")))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        app.openDocument = { [weak self] url, completion in
            guard let self else { return }
            let model = DocumentWindowModel(appModel: app, profileName: app.pendingProfile(for: url),
                                            fileSource: { FakeFileSource() })
            app.register(model)
            model.documentOpened(text: "x", fileURL: url)
            model.hostWindow = NSWindow()
            models.append(model)
            completion(nil)
        }
    }

    func file(_ name: String) throws -> String {
        let url = folder.appendingPathComponent(name)
        try "x".write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    func session() throws -> SavedSession {
        SavedSession(groups: [SavedTabGroup(frame: "{{0, 0}, {600, 400}}",
                                            tabs: [SavedTab(path: try file("a.md"), profile: "Default"),
                                                   SavedTab(path: try file("b.md"), profile: "Blog")],
                                            selected: 0)],
                     frontGroup: 0)
    }

    func testOnlyANormalLaunchSaves() throws {
        app.saveSessionNow()
        XCTAssertNil(app.store.loadSession())
        app.launchKind = .normal
        app.saveSessionNow()
        XCTAssertNotNil(app.store.loadSession())
    }

    func testNothingIsSavedAfterQuitStarts() throws {
        app.launchKind = .normal
        app.stopSavingSession()
        try FileManager.default.removeItem(at: app.store.directory.appendingPathComponent("session.json"))
        app.saveSessionNow()
        XCTAssertNil(app.store.loadSession())
    }

    func testRestoreNeedsANormalLaunchAndTheSetting() throws {
        try app.store.saveSession(try session())
        XCTAssertNil(app.sessionToRestore())
        app.launchKind = .normal
        XCTAssertNotNil(app.sessionToRestore())
        app.reopenWindows = false
        XCTAssertNil(app.sessionToRestore())
    }

    func testRestoreOpensEachFileWithItsProfile() async throws {
        await app.restore(try session())
        XCTAssertEqual(models.map { $0.fileURL?.lastPathComponent }, ["a.md", "b.md"])
        XCTAssertEqual(models.map(\.profileName), [app.defaultProfileName, "Blog"])
    }
}
