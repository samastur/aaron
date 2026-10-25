import AaronAI
import AaronCore
import SwiftUI
import XCTest
@testable import Aaron

@MainActor
final class DocumentWindowModelTests: XCTestCase {
    /// Text views hold their delegates weakly; keep coordinators alive.
    private var coordinators: [EditorView.Coordinator] = []

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
        let app = AppModel(store: ProfileStore(directory: directory))
        app.settingsConfiguration.aiProviders = [AIProviderConfig(id: "slow", name: "Slow",
                                                          command: "cat >/dev/null; sleep 5; echo '{\"suggestions\": []}'")]
        app.settingsConfiguration.aiActions = [AIActionConfig(id: "a", name: "A", prompt: "p", providerID: "slow")]
        let model = DocumentWindowModel(appModel: app)
        model.documentOpened(text: "Text", fileURL: nil)
        model.run(app.settingsConfiguration.aiActions[0])
        try await Task.sleep(for: .milliseconds(200))
        model.cancelAction()
        model.run(app.settingsConfiguration.aiActions[0])
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(model.isRunningAction, "the second run must still be running")
        model.cancelAction()
    }

    /// A window model wired to a real text view and editor coordinator,
    /// with suggestions from a fake provider.
    func reviewedModel(_ text: String, suggestions json: String) async throws
        -> (DocumentWindowModel, MarkdownTextView, EditorView.Coordinator) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dwm-\(UUID().uuidString)")
        let app = AppModel(store: ProfileStore(directory: directory))
        app.settingsConfiguration.aiProviders = [AIProviderConfig(id: "fake", name: "Fake",
                                                          command: "cat >/dev/null; echo '\(json)'")]
        app.settingsConfiguration.aiActions = [AIActionConfig(id: "a", name: "A", prompt: "p", providerID: "fake")]
        let model = DocumentWindowModel(appModel: app)
        let textView = EditorView.makeTextView()
        var stored = text
        let coordinator = EditorView.Coordinator(text: Binding(get: { stored }, set: { stored = $0 }), model: model)
        coordinator.textView = textView
        textView.delegate = coordinator
        textView.string = text
        textView.textStorage?.delegate = coordinator
        coordinators.append(coordinator)
        model.editor.textView = textView
        model.documentOpened(text: text, fileURL: nil)
        model.run(app.settingsConfiguration.aiActions[0])
        let deadline = Date().addingTimeInterval(10)
        while model.isRunningAction && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        return (model, textView, coordinator)
    }

    let story = "Teh cat sat. It was happy."
    let twoSuggestions = #"{"suggestions": [{"original": "Teh", "replacement": "The big", "message": "m"}, {"original": "happy", "replacement": "glad", "message": "m"}]}"#

    func testAcceptMovesOtherSuggestionsExactlyOnce() async throws {
        let (model, textView, _) = try await reviewedModel(story, suggestions: twoSuggestions)
        let first = try XCTUnwrap(model.session.highlights.first)
        model.accept(first.id)
        XCTAssertEqual(textView.string, "The big cat sat. It was happy.")
        let happy = try XCTUnwrap(model.session.suggestions.first { $0.original == "happy" })
        XCTAssertEqual(happy.range, (textView.string as NSString).range(of: "happy"))
    }

    func testRevertPutsTheOriginalBackAndReopens() async throws {
        let (model, textView, _) = try await reviewedModel(story, suggestions: twoSuggestions)
        let first = try XCTUnwrap(model.session.highlights.first)
        model.accept(first.id)
        XCTAssertTrue(model.canRestore(first.id))
        model.restore(first.id)
        XCTAssertEqual(textView.string, story)
        XCTAssertEqual(model.session.suggestion(withID: first.id)?.status, .open)
        let happy = try XCTUnwrap(model.session.suggestions.first { $0.original == "happy" })
        XCTAssertEqual(happy.range, (story as NSString).range(of: "happy"))
        // The revert is an ordinary undoable edit.
        XCTAssertEqual(textView.undoManager?.undoActionName ?? "Revert Suggestion", "Revert Suggestion")
    }

    func testDismissedSuggestionCanBeReopened() async throws {
        let (model, _, _) = try await reviewedModel(story, suggestions: twoSuggestions)
        let first = try XCTUnwrap(model.session.highlights.first)
        model.dismiss(first.id)
        XCTAssertTrue(model.canRestore(first.id))
        model.restore(first.id)
        XCTAssertEqual(model.session.suggestion(withID: first.id)?.status, .open)
        XCTAssertEqual(model.selectedSuggestionID, first.id)
    }

    func testConfigurationChangeUnrelatedToWindowDoesNotRerunTags() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dwm-\(UUID().uuidString)")
        let app = AppModel(store: ProfileStore(directory: directory))
        let counter = directory.appendingPathComponent("count")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        app.settingsConfiguration.pelican.tagsCommand = "echo x >> '\(counter.path)'; echo tag"
        let model = DocumentWindowModel(appModel: app)
        model.documentOpened(text: "Title: T\nTags: a\n\nBody", fileURL: nil)
        let deadline = Date().addingTimeInterval(20)
        while model.tags.isEmpty && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertEqual(model.tags.map(\.name), ["tag"])
        let old = app.settingsConfiguration
        app.settingsConfiguration.aiActions[0].prompt += " More."
        model.configurationChanged(from: old)
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(try String(contentsOf: counter, encoding: .utf8), "x\n")
    }

    // MARK: - Profiles

    /// An app with profiles A (external renderer for Pelican posts) and B
    /// (never Pelican, no renderers).
    func twoProfileApp() throws -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dwm-\(UUID().uuidString)")
        let store = ProfileStore(directory: directory)
        var a = Configuration.default
        a.previewRenderers = [PreviewRendererConfig(id: "external", name: "External", command: "cat")]
        a.defaultRenderer.pelican = "external"
        var b = Configuration.default
        b.pelican.detection = .never
        try store.save(a, as: "A")
        try store.save(b, as: "B")
        try store.setDefaultProfile("A")
        return AppModel(store: store)
    }

    let pelicanPost = "Title: T\nTags: x\n\nBody\n"

    func testWindowStartsWithDefaultProfile() throws {
        let app = try twoProfileApp()
        let model = DocumentWindowModel(appModel: app)
        XCTAssertEqual(model.profileName, "A")
        XCTAssertEqual(DocumentWindowModel(appModel: app, profileName: "B").profileName, "B")
    }

    func testSwitchingProfileChangesRendererAndDetection() throws {
        let app = try twoProfileApp()
        let model = DocumentWindowModel(appModel: app)
        model.documentOpened(text: pelicanPost, fileURL: nil)
        XCTAssertTrue(model.isPelican)
        XCTAssertEqual(model.rendererID, "external")
        model.profileName = "B"
        XCTAssertFalse(model.isPelican)
        XCTAssertEqual(model.rendererID, PreviewRendererConfig.builtinID)
        XCTAssertEqual(model.configuration.pelican.detection, .never)
    }

    func testSwitchingKeepsSuggestions() async throws {
        let (model, _, _) = try await reviewedModel("The cat saw teh fox.", suggestions:
            #"{"suggestions": [{"original": "teh", "replacement": "the", "message": "typo"}]}"#)
        XCTAssertEqual(model.session.suggestions.count, 1)
        let name = try model.appModel.addProfile(copying: model.profileName)
        model.profileName = name
        XCTAssertEqual(model.session.suggestions.count, 1)
    }

    func testEditingOtherProfileDoesNotTouchWindow() throws {
        let app = try twoProfileApp()
        let model = DocumentWindowModel(appModel: app)
        app.register(model)
        model.documentOpened(text: pelicanPost, fileURL: nil)
        var b = app.configuration(for: "B")
        b.previewRenderers = []
        b.pelican.detection = .always
        app.setConfiguration(b, for: "B")
        XCTAssertEqual(model.rendererID, "external")
        XCTAssertTrue(model.isPelican)
    }

    func testEditingOwnProfileRefreshesWindow() throws {
        let app = try twoProfileApp()
        let model = DocumentWindowModel(appModel: app)
        app.register(model)
        model.documentOpened(text: pelicanPost, fileURL: nil)
        var a = app.configuration(for: "A")
        a.previewRenderers = []
        app.setConfiguration(a, for: "A")
        XCTAssertEqual(model.rendererID, PreviewRendererConfig.builtinID)
    }

    func testRenamingProfileKeepsWindowOnIt() throws {
        let app = try twoProfileApp()
        let model = DocumentWindowModel(appModel: app, profileName: "B")
        app.register(model)
        try app.renameProfile("B", to: "Plain")
        XCTAssertEqual(model.profileName, "Plain")
        XCTAssertEqual(model.configuration.pelican.detection, .never)
    }

    func testDeletingProfileMovesItsWindowsToDefault() throws {
        let app = try twoProfileApp()
        let model = DocumentWindowModel(appModel: app, profileName: "B")
        app.register(model)
        model.documentOpened(text: pelicanPost, fileURL: nil)
        XCTAssertFalse(model.isPelican)
        try app.deleteProfile("B")
        XCTAssertEqual(model.profileName, "A")
        XCTAssertTrue(model.isPelican)
    }
}
