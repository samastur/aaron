import AaronCore
import AaronFiles
import XCTest
@testable import Aaron

@MainActor
final class FakeFileSource: FileSource {
    var started: [(root: URL, extensions: Set<String>)] = []
    var stopped = 0
    var update: (@MainActor (FileSourceEvent) -> Void)?

    func start(root: URL, extensions: Set<String>, update: @escaping @MainActor (FileSourceEvent) -> Void) {
        started.append((root, extensions))
        self.update = update
    }

    func stop() { stopped += 1 }
    func send(_ event: FileSourceEvent) { update?(event) }
}

@MainActor
final class FilePanelModelTests: XCTestCase {
    var root: URL!
    var source: FakeFileSource!
    var panel: FilePanelModel!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("panel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        source = FakeFileSource()
        let source = source!
        panel = FilePanelModel(makeSource: { source })
        var settings = FileSettings()
        settings.root = root.path
        panel.configure(settings)
        panel.setActive(true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    func file(_ path: String) -> URL { root.appendingPathComponent(path) }

    func testStartsSourceOnRootWithExtensions() {
        XCTAssertEqual(source.started.count, 1)
        XCTAssertEqual(source.started.first?.root.standardizedFileURL, root.standardizedFileURL)
        XCTAssertEqual(source.started.first?.extensions, ["md", "markdown"])
        XCTAssertEqual(panel.state, .loading)
    }

    func testFinishedResultsBuildTree() {
        source.send(.progress([file("a/one.md")]))
        XCTAssertEqual(panel.state, .loading)
        XCTAssertEqual(panel.nodes.map(\.name), ["a"])
        source.send(.finished([file("a/one.md"), file("two.md")]))
        XCTAssertEqual(panel.state, .ready)
        XCTAssertEqual(panel.nodes.map(\.name), ["a", "two.md"])
    }

    func testEmptyIndexedRootShowsEmpty() {
        source.send(.finished([]))
        XCTAssertEqual(panel.state, .empty)
    }

    func testRevealExpandsAncestors() {
        source.send(.finished([file("a/b/one.md")]))
        panel.reveal(file("a/b/one.md"))
        XCTAssertTrue(panel.expanded.contains(file("a").path))
        XCTAssertTrue(panel.expanded.contains(file("a/b").path))
    }

    func testFilterUsesFoundFiles() {
        source.send(.finished([file("a/Notes.md"), file("other.md")]))
        panel.filter = "note"
        XCTAssertEqual(panel.matches.map(\.name), ["Notes.md"])
        source.send(.updated([file("a/Notes.md"), file("more notes.md")]))
        XCTAssertEqual(Set(panel.matches.map(\.name)), ["Notes.md", "more notes.md"])
    }

    func testNotIndexedSwitchesToFallback() throws {
        try FileManager.default.createDirectory(at: file("sub"), withIntermediateDirectories: true)
        try Data().write(to: file("sub/x.md"))
        try Data().write(to: file("top.md"))
        source.send(.notIndexed)
        XCTAssertEqual(panel.state, .fallback)
        XCTAssertFalse(panel.isFilterEnabled)
        XCTAssertEqual(panel.nodes.map(\.name), ["sub", "top.md"])
        let sub = file("sub")
        XCTAssertEqual(panel.children(of: sub).map(\.name), [])
        panel.expanded.insert(sub.path)
        XCTAssertEqual(panel.children(of: sub).map(\.name), ["x.md"])
        panel.filter = "top"
        XCTAssertTrue(panel.matches.isEmpty)
    }

    func testMissingRootShowsMissing() {
        let source = FakeFileSource()
        let panel = FilePanelModel(makeSource: { source })
        var settings = FileSettings()
        settings.root = root.appendingPathComponent("gone").path
        panel.configure(settings)
        panel.setActive(true)
        XCTAssertEqual(panel.state, .missing)
        XCTAssertTrue(source.started.isEmpty)
    }

    func testReconfigureRestartsSource() {
        var settings = FileSettings()
        settings.root = root.path
        panel.configure(settings)
        XCTAssertEqual(source.started.count, 1, "same settings must not restart")
        settings.extensions = ["txt"]
        panel.configure(settings)
        XCTAssertEqual(source.started.count, 2)
        XCTAssertEqual(source.started.last?.extensions, ["txt"])
    }

    func testHidingStopsSource() {
        panel.setActive(false)
        XCTAssertEqual(source.stopped, 1)
        panel.setActive(true)
        XCTAssertEqual(source.started.count, 2)
    }

    func testProfileSwitchAppliesFilesPane() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dwm-\(UUID().uuidString)")
        let app = AppModel(store: ProfileStore(directory: directory))
        let name = try app.addProfile(copying: app.defaultProfileName)
        var other = app.configuration(for: name)
        other.panes.files = false
        app.setConfiguration(other, for: name)
        let source = FakeFileSource()
        let model = DocumentWindowModel(appModel: app, fileSource: { source })
        model.documentOpened(text: "Text", fileURL: nil)
        XCTAssertTrue(model.showFiles)
        model.profileName = name
        XCTAssertFalse(model.showFiles)
        XCTAssertGreaterThanOrEqual(source.stopped, 1)
    }
}
