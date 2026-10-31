import AaronCore
import AaronFiles
import Foundation
import Observation

/// The file panel of one window: the Markdown files under the profile's
/// root folder, as a tree and as filter results.
@MainActor
@Observable
final class FilePanelModel {
    enum State: Equatable {
        /// Spotlight's first search is still running.
        case loading
        case ready
        /// Indexed, but no Markdown files under the root.
        case empty
        /// Spotlight doesn't index the root; folders are read as expanded.
        case fallback
        /// The root folder doesn't exist.
        case missing
    }

    private(set) var state = State.loading
    private(set) var nodes: [FileNode] = []
    private(set) var files: [URL] = []
    private(set) var root: URL
    private(set) var settings = FileSettings()
    /// Paths of expanded folders. Paths, not URLs: a folder URL may or may
    /// not end in a slash, which makes otherwise equal URLs differ.
    var expanded: Set<String> = [] {
        didSet { if state == .fallback { loadExpandedFolders() } }
    }
    var filter = "" {
        didSet { updateMatches() }
    }
    private(set) var matches: [FileMatch] = []
    /// Folder contents read in fallback mode.
    private var folderContents: [String: [FileNode]] = [:]

    @ObservationIgnored private let makeSource: () -> FileSource
    @ObservationIgnored private var source: FileSource?
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var revealed: URL?

    init(makeSource: @escaping () -> FileSource) {
        self.makeSource = makeSource
        root = FileSettings().rootURL
    }

    var isFilterEnabled: Bool { state != .fallback && state != .missing }

    /// Uses new settings; restarts the search when they changed.
    func configure(_ settings: FileSettings) {
        guard settings != self.settings || source == nil else { return }
        self.settings = settings
        if isActive { restart() } else { root = settings.rootURL }
    }

    /// The panel is shown or hidden; the search runs only while it's shown.
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active { restart() } else { stopSource() }
    }

    /// Shows the window's document: expands the folders leading to it.
    func reveal(_ file: URL?) {
        revealed = file?.standardizedFileURL
        expandRevealed()
    }

    /// A folder's contents in fallback mode, read when it was expanded.
    func children(of folder: URL) -> [FileNode] {
        folderContents[folder.standardizedFileURL.path] ?? []
    }

    private func restart() {
        stopSource()
        nodes = []
        files = []
        folderContents = [:]
        matches = []
        root = settings.rootURL.standardizedFileURL
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isFolder), isFolder.boolValue else {
            state = .missing
            return
        }
        state = .loading
        let source = makeSource()
        self.source = source
        source.start(root: root, extensions: settings.normalizedExtensions) { [weak self, weak source] event in
            guard let self, let source, source === self.source else { return }
            self.handle(event)
        }
    }

    private func stopSource() {
        source?.stop()
        source = nil
    }

    private func handle(_ event: FileSourceEvent) {
        switch event {
        case .progress(let urls):
            update(urls)
        case .finished(let urls), .updated(let urls):
            update(urls)
            state = urls.isEmpty ? .empty : .ready
        case .notIndexed:
            state = .fallback
            files = []
            matches = []
            nodes = read(root)
            loadExpandedFolders()
        }
    }

    private func update(_ urls: [URL]) {
        files = urls
        nodes = FileTreeBuilder(root: root, ignoredFolders: settings.ignoredFolders,
                                iCloudDrive: FileTreeBuilder.defaultICloudDrive,
                                isHidden: FileTreeBuilder.isHiddenOnDisk).build(urls)
        updateMatches()
        expandRevealed()
    }

    private func read(_ folder: URL) -> [FileNode] {
        FolderReader().contents(of: folder, extensions: settings.normalizedExtensions,
                                ignoredFolders: settings.ignoredFolders)
    }

    private func loadExpandedFolders() {
        for folder in expanded where folderContents[folder] == nil {
            folderContents[folder] = read(URL(fileURLWithPath: folder, isDirectory: true))
        }
    }

    private func updateMatches() {
        matches = isFilterEnabled ? filterFiles(files, root: root, query: filter) : []
    }

    private func expandRevealed() {
        guard let revealed else { return }
        let rootDepth = root.pathComponents.count
        var folder = revealed.deletingLastPathComponent()
        var ancestors: [String] = []
        while folder.pathComponents.count > rootDepth {
            ancestors.append(folder.standardizedFileURL.path)
            folder = folder.deletingLastPathComponent()
        }
        guard folder.standardizedFileURL.path == root.path else { return }
        let missing = ancestors.filter { !expanded.contains($0) }
        if !missing.isEmpty { expanded.formUnion(missing) }
    }
}
