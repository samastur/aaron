import AaronCore
import AppKit
import XCTest
@testable import Aaron

@MainActor
final class TabsTests: XCTestCase {
    var app: AppModel!
    var created = 0
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tabs-\(UUID().uuidString)")

    override func setUp() async throws {
        app = AppModel(store: ProfileStore(directory: folder))
        app.newDocument = { [weak self] in self?.created += 1 }
    }

    func testTabKeysChooseTabsAndTheLast() {
        XCTAssertEqual(TabKeys.index(forKey: 1, tabCount: 3), 0)
        XCTAssertEqual(TabKeys.index(forKey: 3, tabCount: 3), 2)
        XCTAssertNil(TabKeys.index(forKey: 4, tabCount: 3))
        XCTAssertEqual(TabKeys.index(forKey: 9, tabCount: 3), 2)
        XCTAssertEqual(TabKeys.index(forKey: 9, tabCount: 12), 11)
        XCTAssertNil(TabKeys.index(forKey: 1, tabCount: 1), "a window without tabs")
        XCTAssertNil(TabKeys.index(forKey: 9, tabCount: 0))
    }

    func testNewTabTakesTheWindowsProfileAndWindow() throws {
        let other = try app.addProfile(copying: app.defaultProfileName)
        let window = DocumentWindowModel(appModel: app, profileName: other)
        let host = NSWindow()
        window.hostWindow = host
        app.newTab(from: window)
        XCTAssertEqual(created, 1)
        let tab = try XCTUnwrap(app.takeNewTab())
        XCTAssertEqual(tab.profile, other)
        XCTAssertTrue(tab.parent === host)
        XCTAssertNil(app.takeNewTab(), "returned once")
    }

    func testNewTabWithoutAWindowUsesTheDefaultProfile() throws {
        app.newTab(from: nil)
        let tab = try XCTUnwrap(app.takeNewTab())
        XCTAssertEqual(tab.profile, app.defaultProfileName)
        XCTAssertNil(tab.parent)
    }

    func testUnclaimedNewTabExpires() {
        app.newTab(from: nil)
        XCTAssertNil(app.takeNewTab(now: Date().addingTimeInterval(NewTab.lifetime + 1)))
    }

    func testProfileOnlyRequestOpensUntitledWithIt() throws {
        let other = try app.addProfile(copying: app.defaultProfileName)
        app.handle(OpenRequest(token: try app.store.cliToken(), profile: other, paths: []).url)
        XCTAssertEqual(created, 1)
        XCTAssertEqual(app.takeNewTab()?.profile, other)
    }
}
