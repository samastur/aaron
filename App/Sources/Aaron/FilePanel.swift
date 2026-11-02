import AaronCore
import AaronFiles
import AppKit
import SwiftUI

/// The file panel: the profile's root folder, a filter and the Markdown
/// files below the root.
struct FilePanel: View {
    @Bindable var model: DocumentWindowModel
    @Environment(AppModel.self) private var appModel
    @FocusState private var focus: Focus?
    @State private var treeSelection: URL?
    @State private var matchSelection: URL?
    /// A file waiting for the user to confirm losing review work.
    @State private var confirming: URL?

    private enum Focus { case filter, matches }

    private var files: FilePanelModel { model.files }

    var body: some View {
        @Bindable var files = model.files
        VStack(spacing: 0) {
            header
            TextField("Filter", text: $files.filter)
                .textFieldStyle(.roundedBorder)
                .disabled(!files.isFilterEnabled)
                .focused($focus, equals: .filter)
                .onKeyPress(.downArrow) {
                    guard !files.matches.isEmpty else { return .ignored }
                    matchSelection = files.matches.first?.url
                    focus = .matches
                    return .handled
                }
                .onExitCommand { files.filter = "" }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .accessibilityIdentifier("fileFilter")
            if files.state == .fallback {
                note("Search needs Spotlight, which doesn't index this folder.")
                    .padding(.bottom, 6)
            }
            Divider()
            content
        }
        .onChange(of: model.fileURL, initial: true) { _, url in treeSelection = url }
        .alert(confirmTitle, isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
               presenting: confirming) { url in
            Button("Open in New Window") {
                appModel.openFromPanel(url, from: model, inNewWindow: true)
                showOwnFile()
            }
            .keyboardShortcut(.defaultAction)
            Button("Replace", role: .destructive) {
                if model.isRunningAction { model.cancelAction() }
                appModel.openFromPanel(url, from: model, inNewWindow: false)
                showOwnFile()
            }
            Button("Cancel", role: .cancel) { showOwnFile() }
        } message: { _ in
            Text(model.reviewLossMessage)
        }
    }

    private var confirmTitle: String {
        "Open “\(confirming?.lastPathComponent ?? "")” in this window?"
    }

    private var header: some View {
        HStack(spacing: 6) {
            Menu {
                Button("Choose Root Folder…") { chooseRoot() }
                Button("Use Home Folder") { setRoot(nil) }
                Divider()
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([files.root]) }
            } label: {
                Label(FileManager.default.displayName(atPath: files.root.path), systemImage: "folder")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(files.root.path)
            .accessibilityIdentifier("fileRoot")
            Spacer()
            if files.state == .loading {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if files.state == .missing {
            placeholder("Folder not found")
        } else if !files.filter.trimmingCharacters(in: .whitespaces).isEmpty && files.isFilterEnabled {
            matchList
        } else if files.state == .empty {
            placeholder("No Markdown files here")
        } else {
            List(selection: selection($treeSelection)) {
                FileTreeRows(nodes: files.nodes, files: files, open: { openFile($0, inNewWindow: $1) }, setRoot: setRoot)
            }
            .listStyle(.sidebar)
            .onKeyPress(.return) { openSelected(treeSelection) }
            .accessibilityIdentifier("fileTree")
        }
    }

    private var matchList: some View {
        List(files.matches, selection: selection($matchSelection)) { match in
            VStack(alignment: .leading, spacing: 1) {
                Text(match.name)
                if !match.folder.isEmpty {
                    Text(match.folder).font(.caption).foregroundStyle(.secondary)
                }
            }
            .tag(match.url)
            .fileContextMenu(match.url) { openFile($0, inNewWindow: $1) }
            .overlay(MiddleClickCatcher { openFile(match.url, inNewWindow: true) })
        }
        .listStyle(.sidebar)
        .focused($focus, equals: .matches)
        .onKeyPress(.return) { openSelected(matchSelection) }
        .accessibilityIdentifier("fileMatches")
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
    }

    /// A list selection that opens files chosen with the mouse; the arrow
    /// keys only move the selection, and Return opens it.
    private func selection(_ state: Binding<URL?>) -> Binding<URL?> {
        Binding(get: { state.wrappedValue }, set: { url in
            state.wrappedValue = url
            guard let url, let event = NSApp.currentEvent,
                  event.type == .leftMouseDown || event.type == .leftMouseUp else { return }
            openFile(url, inNewWindow: event.modifierFlags.contains(.command))
        })
    }

    private func openSelected(_ url: URL?) -> KeyPress.Result {
        guard let url else { return .ignored }
        openFile(url, inNewWindow: false)
        return .handled
    }

    private func openFile(_ url: URL, inNewWindow: Bool) {
        if !inNewWindow, model.hasUnfinishedReview, !(model.fileURL.map { AppModel.isSameFile($0, url) } ?? false) {
            confirming = url
            return
        }
        appModel.openFromPanel(url, from: model, inNewWindow: inNewWindow)
        showOwnFile()
    }

    /// Selects the window's own document again. Selection opens files only
    /// when it changes, so leaving another file selected (after ⌘-click,
    /// Cancel, or a close that was cancelled) would make clicking it again
    /// do nothing.
    private func showOwnFile() {
        treeSelection = model.fileURL
        matchSelection = nil
    }

    private func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = files.root
        panel.prompt = "Use as Root"
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let url = panel.url { setRoot(url) }
        }
        if let window = model.hostWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }

    /// Changes the profile's root folder; nil means the home folder.
    private func setRoot(_ url: URL?) {
        appModel.setFileRoot(url, for: model.profileName)
    }
}

/// The rows of one folder level, with subfolders as disclosure groups.
private struct FileTreeRows: View {
    let nodes: [FileNode]
    let files: FilePanelModel
    let open: (URL, Bool) -> Void
    let setRoot: (URL?) -> Void

    var body: some View {
        ForEach(nodes) { node in
            switch node {
            case .folder(let folder):
                let path = folder.url.standardizedFileURL.path
                DisclosureGroup(isExpanded: Binding(
                    get: { files.expanded.contains(path) },
                    set: { if $0 { files.expanded.insert(path) } else { files.expanded.remove(path) } })) {
                    FileTreeRows(nodes: files.state == .fallback ? files.children(of: folder.url) : folder.children,
                                 files: files, open: open, setRoot: setRoot)
                } label: {
                    Label(folder.name, systemImage: folder.isICloudDrive ? "icloud" : "folder")
                        .contextMenu {
                            Button("Use as Root") { setRoot(folder.url) }
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([folder.url]) }
                        }
                }
            case .file(let url):
                Label(url.lastPathComponent, systemImage: "doc.text")
                    .tag(url)
                    .fileContextMenu(url, open: open)
                    .overlay(MiddleClickCatcher { open(url, true) })
            }
        }
    }
}

private extension View {
    func fileContextMenu(_ url: URL, open: @escaping (URL, Bool) -> Void) -> some View {
        contextMenu {
            Button("Open in New Window") { open(url, true) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
    }
}

/// Catches middle clicks on a row and lets every other click through.
struct MiddleClickCatcher: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> CatcherView { CatcherView(action: action) }
    func updateNSView(_ view: CatcherView, context: Context) { view.action = action }

    final class CatcherView: NSView {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let type = NSApp.currentEvent?.type, type == .otherMouseDown || type == .otherMouseUp else { return nil }
            return super.hitTest(point)
        }

        override func otherMouseDown(with event: NSEvent) {}

        override func otherMouseUp(with event: NSEvent) {
            if event.buttonNumber == 2 { action() }
        }
    }
}
