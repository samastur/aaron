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

    func testAlreadyOpenFileIsNotReopened() {
        let first = window("a.md")
        let second = window("b.md")
        XCTAssertEqual(app.openFromPanel(file("b.md"), from: first, inNewWindow: false), .broughtForward)
        XCTAssertEqual(app.openFromPanel(file("b.md"), from: first, inNewWindow: true), .broughtForward)
        XCTAssertTrue(opened.isEmpty)
        withExtendedLifetime(second) {}
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
}
