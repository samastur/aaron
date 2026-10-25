import AaronAI
import AaronCore
import AaronPelican
import AaronPreview
import Foundation
import Observation

/// State and behaviour of one document window: preview, review mode and
/// Pelican tags. The text itself lives in the document and the text view.
@MainActor
@Observable
final class DocumentWindowModel {
    let appModel: AppModel
    let editor = EditorController()

    private(set) var text = ""
    private(set) var fileURL: URL?
    private(set) var isPelican = false
    private(set) var statistics = TextStatistics(words: 0, characters: 0)

    // Preview
    var showPreview = true {
        didSet { if showPreview && !oldValue { refreshPreview() } }
    }
    var rendererID = PreviewRendererConfig.builtinID {
        didSet { if rendererID != oldValue { refreshPreview(immediately: true) } }
    }
    private(set) var previewHTML: String?
    private(set) var previewError: String?
    private(set) var isRenderingPreview = false
    /// A render is scheduled or running.
    private(set) var isPreviewPending = false
    private var rendererChosen = false

    // Review
    var showReview = false
    private(set) var session = ReviewSession()
    private(set) var selectedSuggestionID: UUID?
    private(set) var runningActionName: String?
    var aiError: String?
    /// Outcome of the last AI action, e.g. how many suggestions it made.
    var aiNotice: String?
    var showHandledSuggestions = false

    // Pelican tags
    private(set) var tags: [TagInfo] = []
    private(set) var tagError: String?
    private var tagsLoadedFor: String?

    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var actionTask: Task<Void, Never>?
    /// Identifies the current run, so a cancelled run finishing late
    /// doesn't reset the state of a newer one.
    @ObservationIgnored private var actionRunID = UUID()
    @ObservationIgnored private var tagTask: Task<Void, Never>?

    /// The profile whose settings this window uses.
    var profileName: String {
        didSet {
            guard profileName != oldValue, !followingRename else { return }
            configurationChanged(from: appModel.configuration(for: oldValue))
        }
    }
    @ObservationIgnored private var followingRename = false

    init(appModel: AppModel, profileName: String? = nil) {
        self.appModel = appModel
        self.profileName = profileName ?? appModel.defaultProfileName
    }

    var configuration: Configuration { appModel.configuration(for: profileName) }

    /// The profile was renamed; its settings are unchanged.
    func profileRenamed(to name: String) {
        followingRename = true
        profileName = name
        followingRename = false
    }

    /// Moves to another profile when the previous one's settings are no
    /// longer available, e.g. because it was deleted.
    func switchProfile(to name: String, previous: Configuration) {
        followingRename = true
        profileName = name
        followingRename = false
        configurationChanged(from: previous)
    }

    var availableRenderers: [(id: String, name: String)] {
        [(PreviewRendererConfig.builtinID, "Markdown (built-in)")]
            + configuration.previewRenderers.map { ($0.id, $0.name) }
    }

    var isRunningAction: Bool { runningActionName != nil }

    // MARK: - Document changes

    func documentOpened(text: String, fileURL: URL?) {
        self.fileURL = fileURL
        textChanged(text)
        if !rendererChosen {
            rendererChosen = true
            rendererID = configuration.defaultRendererID(isPelican: isPelican)
        }
        refreshPreview(immediately: true)
    }

    func fileURLChanged(_ url: URL?) {
        guard url != fileURL else { return }
        fileURL = url
        tagsLoadedFor = nil
        loadTagsIfNeeded()
        refreshPreview()
    }

    func textChanged(_ newText: String) {
        guard newText != text else { return }
        text = newText
        let wasPelican = isPelican
        isPelican = PelicanDetector.isPelican(newText, detection: configuration.pelican.detection)
        statistics = TextStatistics(text: newText)
        if isPelican && !wasPelican { loadTagsIfNeeded() }
        refreshPreview()
    }

    func configurationChanged(from old: Configuration) {
        let new = configuration
        if old.pelican != new.pelican {
            isPelican = PelicanDetector.isPelican(text, detection: new.pelican.detection)
            loadTagsIfNeeded()
        }
        if rendererID != PreviewRendererConfig.builtinID, new.renderer(withID: rendererID) == nil {
            rendererID = PreviewRendererConfig.builtinID
        } else if old.renderer(withID: rendererID) != new.renderer(withID: rendererID) {
            refreshPreview()
        }
    }

    /// Called for every change of the text storage, including undo and
    /// accepted suggestions, so suggestion ranges stay correct.
    func recordEdit(_ edit: TextEdit) {
        if let own = editAppliedBySession, own == edit {
            // Accepting or reverting already updated the session.
            editAppliedBySession = nil
            return
        }
        session.applyEdit(edit)
    }

    /// An edit the session produced and already accounted for, on its way
    /// through the text view.
    @ObservationIgnored private var editAppliedBySession: TextEdit?

    private func applySessionEdit(_ edit: TextEdit, undoName: String) {
        editAppliedBySession = edit
        editor.apply(edit, undoName: undoName)
        editAppliedBySession = nil
    }

    // MARK: - Preview

    func refreshPreview(immediately: Bool = false) {
        guard showPreview else { return }
        previewTask?.cancel()
        let request = PreviewRequest(text: text, fileURL: fileURL)
        let renderer = currentRenderer()
        let delay: Duration = immediately ? .zero : (rendererID == PreviewRendererConfig.builtinID ? .milliseconds(250) : .milliseconds(800))
        isPreviewPending = true
        previewTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            self?.isRenderingPreview = true
            defer {
                if !Task.isCancelled {
                    self?.isRenderingPreview = false
                    self?.isPreviewPending = false
                }
            }
            do {
                let html = try await renderer.render(request)
                guard !Task.isCancelled, let self else { return }
                self.previewHTML = html
                self.previewError = nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.previewError = error.localizedDescription
            }
        }
    }

    private func currentRenderer() -> any PreviewRenderer {
        if let config = configuration.renderer(withID: rendererID) {
            return ExternalCommandRenderer(config: config)
        }
        return BuiltinMarkdownRenderer()
    }

    var previewAllowsJavaScript: Bool {
        configuration.renderer(withID: rendererID)?.allowsJavaScript ?? false
    }

    var assetResolver: PreviewAssetResolver {
        PreviewAssetResolver(mappings: configuration.renderer(withID: rendererID)?.assetMappings ?? [],
                             documentDirectory: fileURL?.deletingLastPathComponent())
    }

    // MARK: - AI actions

    func run(_ action: AIActionConfig) {
        guard !isRunningAction else { return }
        guard let provider = configuration.provider(for: action) else {
            aiError = "The action “\(action.name)” uses an AI provider that no longer exists. Choose another one in Settings."
            showReview = true
            return
        }
        showReview = true
        aiError = nil
        aiNotice = nil
        runningActionName = action.name
        editor.setEditable(false)
        let runID = UUID()
        actionRunID = runID

        let document = editor.currentText
        let selected = editor.selectedRange
        let selection = selected.length > 0 ? (document as NSString).substring(with: selected) : nil
        let request = AIActionRequest(
            actionPrompt: action.prompt, providerCommand: provider.command,
            timeout: .seconds(provider.timeoutSeconds), document: document, selection: selection,
            workingDirectory: existingDocumentDirectory)

        actionTask = Task { [weak self] in
            do {
                let raws = try await AIActionRunner().run(request)
                guard let self, self.actionRunID == runID else { return }
                if self.editor.currentText == document {
                    let before = Set(self.session.suggestions.map(\.id))
                    self.session.add(raws, actionName: action.name, text: document)
                    self.aiNotice = Self.notice(for: action.name,
                                                added: self.session.suggestions.filter { !before.contains($0.id) })
                    if let first = self.session.highlights.first(where: { !before.contains($0.id) }) {
                        self.select(first.id)
                    }
                } else {
                    self.aiError = "The document changed while “\(action.name)” was running, so its results were discarded. Run it again."
                }
            } catch is CancellationError {
                // Cancelled by the user.
            } catch {
                guard self?.actionRunID == runID else { return }
                self?.aiError = "“\(action.name)” failed. \(error.localizedDescription)"
            }
            if self?.actionRunID == runID { self?.finishAction() }
        }
    }

    static func notice(for actionName: String, added: [Suggestion]) -> String {
        guard !added.isEmpty else { return "“\(actionName)” found nothing to suggest." }
        let unlocated = added.filter { $0.status == .notFound || $0.status == .ambiguous }.count
        var notice = "“\(actionName)” made \(added.count) suggestion\(added.count == 1 ? "" : "s")"
        if unlocated > 0 {
            notice += ", \(unlocated) of them could not be located in the text"
        }
        return notice + "."
    }

    func cancelAction() {
        actionTask?.cancel()
        actionRunID = UUID()
        finishAction()
    }

    private func finishAction() {
        runningActionName = nil
        actionTask = nil
        editor.setEditable(true)
    }

    private var existingDocumentDirectory: URL? {
        guard let dir = fileURL?.deletingLastPathComponent(),
              FileManager.default.fileExists(atPath: dir.path) else { return nil }
        return dir
    }

    // MARK: - Suggestions

    var selectedSuggestion: Suggestion? {
        selectedSuggestionID.flatMap { session.suggestion(withID: $0) }
    }

    var visibleSuggestions: [Suggestion] {
        let order: (Suggestion) -> Int = { $0.range?.location ?? Int.max }
        let active = session.suggestions.filter { [.open, .stale, .notFound, .ambiguous].contains($0.status) }
            .sorted { order($0) < order($1) }
        guard showHandledSuggestions else { return active }
        return active + session.suggestions.filter { $0.status == .accepted || $0.status == .dismissed }
    }

    func select(_ id: UUID?, reveal: Bool = true) {
        selectedSuggestionID = id
        if reveal, let range = selectedSuggestion?.range {
            editor.reveal(range)
        }
    }

    func accept(_ id: UUID) {
        guard !isRunningAction else { return }
        let next = session.nextOpen(after: id)
        if let edit = session.accept(id, in: editor.currentText) {
            applySessionEdit(edit, undoName: "Accept Suggestion")
            select(next?.id == id ? nil : next?.id)
        }
    }

    /// Whether a handled suggestion can be reverted (accepted) or reopened
    /// (dismissed).
    func canRestore(_ id: UUID) -> Bool {
        !isRunningAction && session.canRestore(id, in: editor.currentText)
    }

    /// Reverts an accepted suggestion or reopens a dismissed one, and
    /// selects it.
    func restore(_ id: UUID) {
        guard canRestore(id), let suggestion = session.suggestion(withID: id) else { return }
        if suggestion.status == .accepted {
            guard let edit = session.revert(id, in: editor.currentText) else { return }
            applySessionEdit(edit, undoName: "Revert Suggestion")
        } else {
            session.reopen(id, in: editor.currentText)
        }
        select(id)
    }

    func dismiss(_ id: UUID) {
        let next = session.nextOpen(after: id)
        session.dismiss(id)
        select(next?.id == id ? nil : next?.id)
    }

    func acceptSelected() { selectedSuggestionID.map(accept) }
    func dismissSelected() { selectedSuggestionID.map(dismiss) }

    func selectNext() {
        select(session.nextOpen(after: selectedSuggestionID)?.id)
    }

    func selectPrevious() {
        let ordered = session.highlights
        guard !ordered.isEmpty else { return }
        let current = ordered.firstIndex { $0.id == selectedSuggestionID } ?? 0
        select(ordered[(current - 1 + ordered.count) % ordered.count].id)
    }

    func clearSuggestions() {
        session.clear()
        selectedSuggestionID = nil
        aiError = nil
        aiNotice = nil
    }

    /// Clicking into highlighted text selects its suggestion.
    func caretMoved(to location: Int) {
        guard showReview, let suggestion = session.suggestion(at: location) else { return }
        if suggestion.id != selectedSuggestionID {
            select(suggestion.id, reveal: false)
        }
    }

    // MARK: - Tags

    func loadTagsIfNeeded(refresh: Bool = false) {
        let pelican = configuration.pelican
        guard isPelican, !pelican.tagsCommand.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let context = CommandContext(fileURL: fileURL, baseDirectory: nil, temporaryFileURL: nil)
        let command = CommandTemplate.expand(pelican.tagsCommand, context: context)
        let directory = PathExpansion.url(pelican.tagsWorkingDirectory) ?? existingDocumentDirectory
        let key = command + "|" + (directory?.path ?? "")
        guard refresh || tagsLoadedFor != key else { return }
        tagsLoadedFor = key
        let provider = appModel.tagProvider
        tagTask?.cancel()
        tagTask = Task { [weak self] in
            do {
                let tags = try await provider.tags(command: command, workingDirectory: directory,
                                                   timeout: .seconds(pelican.tagsTimeoutSeconds), refresh: refresh)
                self?.tags = tags
                self?.tagError = nil
            } catch is CancellationError {
                return
            } catch {
                self?.tagError = error.localizedDescription
                self?.tagsLoadedFor = nil
            }
        }
    }
}
