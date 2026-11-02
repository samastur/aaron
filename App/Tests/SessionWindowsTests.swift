import AaronCore
import AppKit
import XCTest
@testable import Aaron

@MainActor
final class SessionWindowsTests: XCTestCase {
    var app: AppModel!
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("sessionwin-\(UUID().uuidString)")

    override func setUp() async throws {
        app = AppModel(store: ProfileStore(directory: folder))
    }

    func testWindowsNotOnScreenAreStillSaved() {
        // Hidden apps and minimized windows report isVisible == false.
        let model = DocumentWindowModel(appModel: app, fileSource: { FakeFileSource() })
        app.register(model)
        model.documentOpened(text: "x", fileURL: folder.appendingPathComponent("a.md"))
        let window = NSWindow()
        XCTAssertFalse(window.isVisible)
        model.hostWindow = window
        let session = app.currentSession(windows: [window])
        XCTAssertEqual(session.groups.map { $0.tabs.map(\.path) }, [[folder.appendingPathComponent("a.md").path]])
    }

    final class TrackingDocument: NSDocument {
        var closed = false
        override func close() { closed = true }
    }

    func testOnlyUntouchedUntitledDocumentsAreClosedAfterRestoring() {
        let untouched = TrackingDocument()
        let typedIn = TrackingDocument()
        // Typed in while the session was being restored.
        typedIn.updateChangeCount(.changeDone)
        AppModel.closeUntouched([untouched, typedIn])
        XCTAssertTrue(untouched.closed)
        XCTAssertFalse(typedIn.closed)
    }
}
