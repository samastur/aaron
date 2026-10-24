import AaronAI
import AaronCore
import XCTest
@testable import Aaron

@MainActor
final class DocumentWindowModelTests: XCTestCase {
    func suggestion(_ status: Suggestion.Status) -> Suggestion {
        Suggestion(id: UUID(), actionName: "A", original: "x", replacement: "y", message: "", category: nil,
                   range: nil, status: status)
    }

    func testNoticeForNoSuggestions() {
        XCTAssertEqual(DocumentWindowModel.notice(for: "Grammar", added: []), "“Grammar” found nothing to suggest.")
    }

    func testNoticeCountsSuggestionsAndUnlocatedOnes() {
        XCTAssertEqual(DocumentWindowModel.notice(for: "Style", added: [suggestion(.open)]),
                       "“Style” made 1 suggestion.")
        XCTAssertEqual(DocumentWindowModel.notice(for: "Style", added: [suggestion(.open), suggestion(.notFound), suggestion(.ambiguous)]),
                       "“Style” made 3 suggestions, 2 of them could not be located in the text.")
    }

    func testCancelThenRunAgainKeepsTheNewActionRunning() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dwm-\(UUID().uuidString)")
        let app = AppModel(configurationURL: directory.appendingPathComponent("config.json"))
        app.configuration.aiProviders = [AIProviderConfig(id: "slow", name: "Slow",
                                                          command: "cat >/dev/null; sleep 5; echo '{\"suggestions\": []}'")]
        app.configuration.aiActions = [AIActionConfig(id: "a", name: "A", prompt: "p", providerID: "slow")]
        let model = DocumentWindowModel(appModel: app)
        model.documentOpened(text: "Text", fileURL: nil)
        model.run(app.configuration.aiActions[0])
        try await Task.sleep(for: .milliseconds(200))
        model.cancelAction()
        model.run(app.configuration.aiActions[0])
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(model.isRunningAction, "the second run must still be running")
        model.cancelAction()
    }

    func testConfigurationChangeUnrelatedToWindowDoesNotRerunTags() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dwm-\(UUID().uuidString)")
        let app = AppModel(configurationURL: directory.appendingPathComponent("config.json"))
        let counter = directory.appendingPathComponent("count")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        app.configuration.pelican.tagsCommand = "echo x >> '\(counter.path)'; echo tag"
        let model = DocumentWindowModel(appModel: app)
        model.documentOpened(text: "Title: T\nTags: a\n\nBody", fileURL: nil)
        let deadline = Date().addingTimeInterval(20)
        while model.tags.isEmpty && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertEqual(model.tags.map(\.name), ["tag"])
        let old = app.configuration
        app.configuration.aiActions[0].prompt += " More."
        model.configurationChanged(from: old)
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(try String(contentsOf: counter, encoding: .utf8), "x\n")
    }
}
