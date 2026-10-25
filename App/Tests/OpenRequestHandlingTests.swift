import AaronCore
import XCTest
@testable import Aaron

@MainActor
final class OpenRequestHandlingTests: XCTestCase {
    nonisolated(unsafe) var directory: URL!
    var opened: [URL] = []

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("OpenRequest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func makeApp() throws -> AppModel {
        let store = ProfileStore(directory: directory.appendingPathComponent("support"))
        try store.save(.default, as: "Default")
        try store.save(.default, as: "Blog")
        try store.setDefaultProfile("Default")
        let app = AppModel(store: store)
        app.openDocument = { [unowned self] in self.opened.append($0) }
        return app
    }

    func request(_ app: AppModel, token: String? = nil, profile: String?, paths: [String]) throws -> URL {
        OpenRequest(token: try token ?? app.store.cliToken(), profile: profile, paths: paths).url
    }

    func testWrongTokenOpensNothing() throws {
        let app = try makeApp()
        _ = try app.store.cliToken()
        app.handle(try request(app, token: "0123456789abcdef0123456789abcdef", profile: nil, paths: ["/tmp/a.md"]))
        XCTAssertEqual(opened, [])
    }

    func testOpensEachPathWithPendingProfile() throws {
        let app = try makeApp()
        app.handle(try request(app, profile: "Blog", paths: ["/tmp/a b.md", "/tmp/c.md"]))
        XCTAssertEqual(opened.map(\.path), ["/tmp/a b.md", "/tmp/c.md"])
        XCTAssertEqual(app.pendingProfile(for: URL(fileURLWithPath: "/tmp/a b.md")), "Blog")
        XCTAssertNil(app.pendingProfile(for: URL(fileURLWithPath: "/tmp/a b.md")), "consumed once")
    }

    func testWithoutProfileThereIsNoPendingProfile() throws {
        let app = try makeApp()
        app.handle(try request(app, profile: nil, paths: ["/tmp/a.md"]))
        XCTAssertEqual(opened.count, 1)
        XCTAssertNil(app.pendingProfile(for: URL(fileURLWithPath: "/tmp/a.md")))
    }

    func testProfileMatchingIgnoresCase() throws {
        let app = try makeApp()
        app.handle(try request(app, profile: "blog", paths: ["/tmp/a.md"]))
        XCTAssertEqual(app.pendingProfile(for: URL(fileURLWithPath: "/tmp/a.md")), "Blog")
    }

    func testUnknownProfileIsReportedAndOpensWithDefault() throws {
        let app = try makeApp()
        app.handle(try request(app, profile: "Nope", paths: ["/tmp/a.md"]))
        XCTAssertEqual(opened.count, 1)
        XCTAssertNil(app.pendingProfile(for: URL(fileURLWithPath: "/tmp/a.md")))
        XCTAssertTrue(app.configurationError?.contains("Nope") == true)
    }

    func testAlreadyOpenFileSwitchesItsWindow() throws {
        let app = try makeApp()
        let file = URL(fileURLWithPath: "/tmp/open.md")
        let window = DocumentWindowModel(appModel: app)
        app.register(window)
        window.documentOpened(text: "x", fileURL: file)
        app.handle(try request(app, profile: "Blog", paths: ["/tmp/./open.md"]))
        XCTAssertEqual(window.profileName, "Blog")
        XCTAssertEqual(opened.count, 1, "still asked to open, which brings it to the front")
        XCTAssertNil(app.pendingProfile(for: file))
    }
}
