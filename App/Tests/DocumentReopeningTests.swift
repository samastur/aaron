import AaronCore
import AppKit
import XCTest
@testable import Aaron

/// Stands in for a future NSDocument whose method changed its parameter.
private final class ChangedDocument: NSObject {
    @objc(_closeOtherDocumentWithURL:) func closeOther(_ count: Int) {}
}

/// Stands in for a future document class that overrides the method itself.
private final class OverridingDocument: NSDocument {
    @objc(_closeOtherDocumentWithURL:) func closeOther(_ url: URL?) {}
}

@MainActor
final class DocumentReopeningTests: XCTestCase {
    /// Fails on a macOS that changed what Aaron relies on: Aaron then turns
    /// off opening a file in several windows, and needs a new build.
    func testThisMacOSHasTheMethodsAaronReplaces() {
        XCTAssertNil(DocumentReopening.problem(controllerClass: NSDocumentController.self,
                                               documentClass: NSDocument.self))
    }

    func testMissingMethodIsAProblem() throws {
        let problem = try XCTUnwrap(DocumentReopening.problem(controllerClass: NSDocumentController.self,
                                                              documentClass: NSObject.self))
        XCTAssertTrue(problem.contains("_closeOtherDocumentWithURL:"), problem)
    }

    func testChangedSignatureIsAProblem() {
        XCTAssertNotNil(DocumentReopening.problem(controllerClass: NSDocumentController.self,
                                                  documentClass: ChangedDocument.self))
    }

    func testDocumentClassOverridingTheReplacedMethodIsAProblem() {
        DocumentReopening.enable()
        let controller: AnyClass = type(of: NSDocumentController.shared)
        XCTAssertNil(DocumentReopening.check(controllerClass: controller, documentClass: NSDocument.self))
        XCTAssertNotNil(DocumentReopening.check(controllerClass: controller, documentClass: OverridingDocument.self))
    }
}

@MainActor
final class CopiesProblemTests: XCTestCase {
    var app: AppModel!
    var alerts: [String] = []
    var defaults: UserDefaults!
    let suite = "CopiesProblemTests-\(UUID().uuidString)"
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("copies-\(UUID().uuidString)")

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suite)
        app = AppModel(store: ProfileStore(directory: folder.appendingPathComponent("support")))
        app.showAlert = { [weak self] _, message in self?.alerts.append(message) }
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func testProblemIsReportedOncePerBuildAndMacOS() {
        app.turnOffCopies(because: "X went away.")
        app.reportCopiesProblem(defaults: defaults, version: "1 on 27.0")
        app.reportCopiesProblem(defaults: defaults, version: "1 on 27.0")
        XCTAssertEqual(alerts.count, 1)
        XCTAssertTrue(alerts[0].contains("X went away."))
        app.reportCopiesProblem(defaults: defaults, version: "1 on 27.1")
        XCTAssertEqual(alerts.count, 2)
    }

    func testNothingIsReportedWithoutAProblem() {
        app.reportCopiesProblem(defaults: defaults, version: "1 on 27.0")
        XCTAssertEqual(alerts, [])
        XCTAssertTrue(app.canOpenCopies)
    }

    func testTurningOffStopsCopies() {
        app.turnOffCopies(because: "X went away.")
        XCTAssertFalse(app.canOpenCopies)
    }
}
