import AaronCore
import XCTest
@testable import Aaron

@MainActor
final class CopyNoteTests: XCTestCase {
    var app: AppModel!
    var models: [DocumentWindowModel] = []
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("copies-\(UUID().uuidString)")

    override func setUp() async throws {
        app = AppModel(store: ProfileStore(directory: folder))
    }

    func open(_ name: String) -> DocumentWindowModel {
        let model = DocumentWindowModel(appModel: app, fileSource: { FakeFileSource() })
        app.register(model)
        model.documentOpened(text: "x", fileURL: folder.appendingPathComponent(name))
        models.append(model)
        return model
    }

    func testOneCopyShowsNoNote() {
        XCTAssertFalse(open("a.md").showsCopyNote)
    }

    func testTwoCopiesBothShowTheNote() {
        let first = open("a.md")
        let second = open("a.md")
        let other = open("b.md")
        XCTAssertTrue(first.showsCopyNote)
        XCTAssertTrue(second.showsCopyNote)
        XCTAssertFalse(other.showsCopyNote)
    }

    func testDismissingHidesTheNoteInThatWindowOnly() {
        let first = open("a.md")
        let second = open("a.md")
        first.dismissCopyNote()
        XCTAssertFalse(first.showsCopyNote)
        XCTAssertTrue(second.showsCopyNote)
    }

    func testAnotherCopyBringsTheNoteBack() {
        let first = open("a.md")
        _ = open("a.md")
        first.dismissCopyNote()
        _ = open("a.md")
        XCTAssertTrue(first.showsCopyNote)
    }

    func testClosingTheOtherCopiesRemovesTheNote() {
        let first = open("a.md")
        let second = open("a.md")
        app.windowClosed(second)
        XCTAssertFalse(first.showsCopyNote)
    }

    func testRenamingAwayRemovesTheNote() {
        let first = open("a.md")
        let second = open("a.md")
        second.fileURLChanged(folder.appendingPathComponent("c.md"))
        XCTAssertFalse(first.showsCopyNote)
        XCTAssertFalse(second.showsCopyNote)
    }
}
