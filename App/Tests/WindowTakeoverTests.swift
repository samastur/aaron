import AaronAI
import AaronCore
import AaronFiles
import XCTest
@testable import Aaron

@MainActor
final class WindowTakeoverTests: XCTestCase {
    var app: AppModel!
    var opened: [URL] = []
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("takeover-\(UUID().uuidString)")

    override func setUp() async throws {
        app = AppModel(store: ProfileStore(directory: folder.appendingPathComponent("support")))
        app.openDocument = { [weak self] url, completion in
            self?.opened.append(url)
            completion(nil)
        }
    }

    func window(_ name: String?) -> DocumentWindowModel {
        let model = DocumentWindowModel(appModel: app, fileSource: { FakeFileSource() })
        app.register(model)
        model.documentOpened(text: "Text", fileURL: name.map { folder.appendingPathComponent($0) })
        return model
    }

    func file(_ name: String) -> URL { folder.appendingPathComponent(name) }

    func testSameFileDoesNothing() {
        let first = window("a.md")
        XCTAssertEqual(app.openFromPanel(file("a.md"), from: first, inNewWindow: false), .nothing)
        XCTAssertTrue(opened.isEmpty)
    }

    func testFileOpenElsewhereOpensAgain() {
        let first = window("a.md")
        let second = window("b.md")
        XCTAssertEqual(app.openFromPanel(file("b.md"), from: first, inNewWindow: false), .replaced)
        XCTAssertEqual(app.openFromPanel(file("b.md"), from: first, inNewWindow: true), .newWindow)
        XCTAssertEqual(opened, [file("b.md"), file("b.md")])
        withExtendedLifetime(second) {}
    }

    func testOwnFileInNewWindowOpensCopy() {
        let first = window("a.md")
        XCTAssertEqual(app.openFromPanel(file("a.md"), from: first, inNewWindow: true), .newWindow)
        XCTAssertEqual(opened, [file("a.md")])
        XCTAssertEqual(app.pendingProfile(for: file("a.md")), first.profileName)
    }

    func testTwoPendingCopiesKeepTheirProfiles() throws {
        let other = try app.addProfile(copying: app.defaultProfileName)
        let first = window("a.md")
        first.profileName = other
        let second = window("b.md")
        app.openFromPanel(file("c.md"), from: first, inNewWindow: true)
        app.openFromPanel(file("c.md"), from: second, inNewWindow: true)
        XCTAssertEqual(app.pendingProfile(for: file("c.md")), other)
        XCTAssertEqual(app.pendingProfile(for: file("c.md")), app.defaultProfileName)
    }

    func testTwoPendingTakeoversOfOneFileAreBothKept() {
        let first = window("a.md")
        let second = window("b.md")
        first.files.filter = "first"
        second.files.filter = "second"
        app.openFromPanel(file("c.md"), from: first, inNewWindow: false)
        app.openFromPanel(file("c.md"), from: second, inNewWindow: false)
        XCTAssertEqual(app.takeover(for: file("c.md"))?.filter, "first")
        XCTAssertEqual(app.takeover(for: file("c.md"))?.filter, "second")
    }

    func testFailedOpenDropsOnlyItsOwnPendingProfile() throws {
        let first = window("a.md")
        var completions: [(Error?) -> Void] = []
        app.openDocument = { _, completion in completions.append(completion) }
        app.openFromPanel(file("c.md"), from: first, inNewWindow: true)
        app.openFromPanel(file("c.md"), from: first, inNewWindow: true)
        completions[0](CocoaError(.fileNoSuchFile))
        XCTAssertNotNil(app.pendingProfile(for: file("c.md")))
        XCTAssertNil(app.pendingProfile(for: file("c.md")))
    }

    func testNewWindowCarriesProfile() throws {
        let other = try app.addProfile(copying: app.defaultProfileName)
        let first = window("a.md")
        first.profileName = other
        XCTAssertEqual(app.openFromPanel(file("c.md"), from: first, inNewWindow: true), .newWindow)
        XCTAssertEqual(opened, [file("c.md")])
        XCTAssertEqual(app.pendingProfile(for: file("c.md")), other)
        XCTAssertNil(app.takeover(for: file("c.md")))
    }

    func testReplaceRecordsTakeoverWithState() {
        let first = window("a.md")
        first.showPreview = false
        first.files.expanded = ["/x"]
        first.files.filter = "note"
        XCTAssertEqual(app.openFromPanel(file("c.md"), from: first, inNewWindow: false), .replaced)
        XCTAssertEqual(opened, [file("c.md")])
        let takeover = app.takeover(for: file("c.md"))
        XCTAssertEqual(takeover?.profile, first.profileName)
        XCTAssertEqual(takeover?.panes, PaneSettings(editor: true, preview: false, review: false, files: true))
        XCTAssertEqual(takeover?.expanded, ["/x"])
        XCTAssertEqual(takeover?.filter, "note")
    }

    func testTakeoverIsReturnedOnce() {
        let first = window("a.md")
        app.openFromPanel(file("c.md"), from: first, inNewWindow: false)
        XCTAssertNotNil(app.takeover(for: file("c.md")))
        XCTAssertNil(app.takeover(for: file("c.md")))
    }

    func testFailedOpenDropsTakeover() {
        app.openDocument = { _, completion in completion(CocoaError(.fileReadNoSuchFile)) }
        let first = window("a.md")
        app.openFromPanel(file("c.md"), from: first, inNewWindow: false)
        XCTAssertNil(app.takeover(for: file("c.md")))
    }

    func testAdoptingTakeoverRestoresState() {
        let first = window("a.md")
        first.showEditor = false
        first.files.expanded = ["/x"]
        app.openFromPanel(file("c.md"), from: first, inNewWindow: false)
        let takeover = app.takeover(for: file("c.md"))!
        let second = window("c.md")
        second.adopt(takeover)
        XCTAssertFalse(second.showEditor)
        XCTAssertTrue(second.files.expanded.contains("/x"))
    }

    func testStaleTakeoverExpires() {
        let first = window("a.md")
        app.openFromPanel(file("c.md"), from: first, inNewWindow: false)
        XCTAssertNil(app.takeover(for: file("c.md"), now: Date().addingTimeInterval(60)))
    }

    /// Refuses to close, like a window asking whether to save.
    final class RefusingDelegate: NSObject, NSWindowDelegate {
        func windowShouldClose(_ sender: NSWindow) -> Bool { false }
    }

    func testOldWindowThatAsksStaysInFront() {
        let old = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 500, height: 400),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        let new = NSWindow(contentRect: NSRect(x: 300, y: 300, width: 200, height: 200),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        old.isReleasedWhenClosed = false
        new.isReleasedWhenClosed = false
        let delegate = RefusingDelegate()
        old.delegate = delegate
        old.orderFront(nil)
        new.orderFront(nil)
        DocumentWindowModel.take(placeOf: old, by: new)
        XCTAssertEqual(new.frame, old.frame)
        XCTAssertTrue(old.isVisible)
        let order = NSApp.orderedWindows
        XCTAssertLessThan(order.firstIndex(of: old) ?? .max, order.firstIndex(of: new) ?? .max,
                          "the window asking must be in front of its replacement")
        old.close()
        new.close()
        withExtendedLifetime(delegate) {}
    }

    func suggestion(_ status: Suggestion.Status) -> Suggestion {
        Suggestion(id: UUID(), actionName: "A", original: "x", replacement: "y", message: "", category: nil,
                   range: nil, status: status)
    }

    func testUnfinishedReviewDetected() {
        XCTAssertFalse(DocumentWindowModel.isUnfinished([suggestion(.accepted), suggestion(.dismissed)], running: false))
        XCTAssertTrue(DocumentWindowModel.isUnfinished([suggestion(.open)], running: false))
        XCTAssertTrue(DocumentWindowModel.isUnfinished([suggestion(.stale)], running: false))
        XCTAssertTrue(DocumentWindowModel.isUnfinished([], running: true))
    }

    func testReviewLossMessage() {
        XCTAssertEqual(DocumentWindowModel.reviewLossMessage(openSuggestions: 3, runningAction: nil, documentName: "first.md"),
                       "The 3 open suggestions for “first.md” will be lost.")
        XCTAssertEqual(DocumentWindowModel.reviewLossMessage(openSuggestions: 1, runningAction: nil, documentName: "first.md"),
                       "The 1 open suggestion for “first.md” will be lost.")
        XCTAssertEqual(DocumentWindowModel.reviewLossMessage(openSuggestions: 0, runningAction: "Style", documentName: "first.md"),
                       "The running “Style” action will be cancelled.")
        XCTAssertEqual(DocumentWindowModel.reviewLossMessage(openSuggestions: 2, runningAction: "Style", documentName: "first.md"),
                       "The running “Style” action will be cancelled. The 2 open suggestions for “first.md” will be lost.")
    }

    // Without copies (a macOS update changed what they rely on), a file
    // open in another window comes forward, as before copies existed.

    func testWithoutCopiesAFileOpenElsewhereComesForward() {
        app.canOpenCopies = false
        let first = window("a.md")
        let second = window("b.md")
        XCTAssertEqual(app.openFromPanel(file("b.md"), from: first, inNewWindow: false), .broughtForward)
        XCTAssertEqual(app.openFromPanel(file("b.md"), from: first, inNewWindow: true), .broughtForward)
        XCTAssertEqual(opened, [])
        XCTAssertTrue(app.pendingTakeovers.isEmpty)
        XCTAssertTrue(app.pendingProfiles.isEmpty)
        XCTAssertEqual(second.fileURL, file("b.md"))
    }

    func testWithoutCopiesTheWindowsOwnFileDoesNothingInANewWindow() {
        app.canOpenCopies = false
        let first = window("a.md")
        XCTAssertEqual(app.openFromPanel(file("a.md"), from: first, inNewWindow: true), .nothing)
        XCTAssertEqual(opened, [])
    }
}
