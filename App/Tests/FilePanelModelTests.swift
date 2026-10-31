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

    /// Sends an event and waits until the tree built from it is shown.
    func send(_ event: FileSourceEvent) async {
        source.send(event)
        await panel.waitForTree()
    }

    func testStartsSourceOnRootWithExtensions() async {
        XCTAssertEqual(source.started.count, 1)
        XCTAssertEqual(source.started.first?.root.standardizedFileURL, root.standardizedFileURL)
        XCTAssertEqual(source.started.first?.extensions, ["md", "markdown"])
        XCTAssertEqual(panel.state, .loading)
    }

    func testFinishedResultsBuildTree() async {
        await send(.progress([file("a/one.md")]))
        XCTAssertEqual(panel.state, .loading)
        XCTAssertEqual(panel.nodes.map(\.name), ["a"])
        await send(.finished([file("a/one.md"), file("two.md")]))
        XCTAssertEqual(panel.state, .ready)
        XCTAssertEqual(panel.nodes.map(\.name), ["a", "two.md"])
    }

    func testEmptyIndexedRootShowsEmpty() async {
        await send(.finished([]))
        XCTAssertEqual(panel.state, .empty)
    }

    func testRevealExpandsAncestors() async {
        await send(.finished([file("a/b/one.md")]))
        panel.reveal(file("a/b/one.md"))
        XCTAssertTrue(panel.expanded.contains(file("a").path))
        XCTAssertTrue(panel.expanded.contains(file("a/b").path))
    }

    func testFilterUsesFoundFiles() async {
        await send(.finished([file("a/Notes.md"), file("other.md")]))
        panel.filter = "note"
        XCTAssertEqual(panel.matches.map(\.name), ["Notes.md"])
        await send(.updated([file("a/Notes.md"), file("more notes.md")]))
        XCTAssertEqual(Set(panel.matches.map(\.name)), ["Notes.md", "more notes.md"])
    }

    func testNotIndexedSwitchesToFallback() async throws {
        try FileManager.default.createDirectory(at: file("sub"), withIntermediateDirectories: true)
        try Data().write(to: file("sub/x.md"))
        try Data().write(to: file("top.md"))
        await send(.notIndexed)
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

    func testMissingRootShowsMissing() async {
        let source = FakeFileSource()
        let panel = FilePanelModel(makeSource: { source })
        var settings = FileSettings()
        settings.root = root.appendingPathComponent("gone").path
        panel.configure(settings)
        panel.setActive(true)
        XCTAssertEqual(panel.state, .missing)
        XCTAssertTrue(source.started.isEmpty)
    }

    func testReconfigureRestartsSource() async {
        var settings = FileSettings()
        settings.root = root.path
        panel.configure(settings)
        XCTAssertEqual(source.started.count, 1, "same settings must not restart")
        settings.extensions = ["txt"]
        panel.configure(settings)
        XCTAssertEqual(source.started.count, 2)
        XCTAssertEqual(source.started.last?.extensions, ["txt"])
    }

    func testFilterSkipsHiddenAndIgnoredFiles() async {
        await send(.finished([file("node_modules/pkg/readme.md"), file(".git/readme.md"), file("a/readme.md")]))
        panel.filter = "readme"
        XCTAssertEqual(panel.matches.map(\.url.path), [file("a/readme.md").path])
    }

    func testLargeResultsAreBuiltOffTheMainThread() async {
        let urls = (0..<20_000).map { file("f\($0 % 50)/g\($0 % 7)/note\($0).md") }
        let start = Date()
        source.send(.finished(urls))
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.05, "handling an event must not build the tree")
        await panel.waitForTree()
        XCTAssertEqual(panel.nodes.count, 50)
        XCTAssertEqual(panel.state, .ready)
    }

    func testLatestResultsWin() async {
        source.send(.progress([file("old.md")]))
        source.send(.finished([file("new.md")]))
        await panel.waitForTree()
        XCTAssertEqual(panel.nodes.map(\.name), ["new.md"])
        XCTAssertEqual(panel.state, .ready)
    }

    func testRootDeletedWhileShownShowsMissing() async throws {
        await send(.finished([file("a.md")]))
        try FileManager.default.removeItem(at: root)
        await send(.updated([]))
        XCTAssertEqual(panel.state, .missing)
    }

    func testHidingStopsSource() async {
        panel.setActive(false)
        XCTAssertEqual(source.stopped, 1)
        panel.setActive(true)
        XCTAssertEqual(source.started.count, 2)
    }

    func testProfileSwitchAppliesFilesPane() async throws {
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
