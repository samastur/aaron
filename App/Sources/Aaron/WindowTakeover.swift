import AaronAI
import AaronCore
import AppKit
import SwiftUI

/// What a window opened from the file panel takes over from the window it
/// replaces, so the switch looks like one window changing its document.
struct Takeover {
    var file: URL
    var profile: String
    var panes: PaneSettings
    var expanded: Set<String>
    var filter: String
    weak var replacing: NSWindow?
    let id = UUID()
    /// A takeover nobody picked up soon after (e.g. the document was
    /// already open) must not hijack a later, unrelated open.
    var created = Date()

    static let lifetime: TimeInterval = 10
}

enum PanelOpenResult: Equatable {
    /// The window already shows the file.
    case nothing
    case newWindow
    case replaced
}

extension AppModel {
    /// Opens a file chosen in a window's file panel: in a new window, or in
    /// place of that window. A file open in another window opens again, and
    /// so does the window's own file in a new window. Asking about lost
    /// review work is up to the caller.
    @discardableResult
    func openFromPanel(_ file: URL, from window: DocumentWindowModel, inNewWindow: Bool) -> PanelOpenResult {
        if !inNewWindow, let current = window.fileURL, Self.isSameFile(current, file) { return .nothing }
        if inNewWindow {
            openDocument(file, profile: window.profileName)
            return .newWindow
        }
        let takeover = Takeover(file: file, profile: window.profileName, panes: window.currentPanes,
                                expanded: window.files.expanded, filter: window.files.filter,
                                replacing: window.hostWindow)
        pendingTakeovers.append(takeover)
        openDocument(file) { [weak self] error in
            if error != nil { self?.pendingTakeovers.removeAll { $0.id == takeover.id } }
        }
        return .replaced
    }

    /// Changes a profile's file panel root; nil means the home folder.
    func setFileRoot(_ url: URL?, for profile: String) {
        var configuration = configuration(for: profile)
        configuration.files.root = url.map { ($0.path as NSString).abbreviatingWithTildeInPath } ?? "~"
        setConfiguration(configuration, for: profile)
    }

    /// The takeover waiting for this file's window; returned once.
    func takeover(for fileURL: URL?, now: Date = Date()) -> Takeover? {
        pendingTakeovers.removeAll { now.timeIntervalSince($0.created) > Takeover.lifetime }
        guard let fileURL,
              let index = pendingTakeovers.firstIndex(where: { Self.isSameFile($0.file, fileURL) }) else { return nil }
        return pendingTakeovers.remove(at: index)
    }
}

extension DocumentWindowModel {
    var currentPanes: PaneSettings {
        PaneSettings(editor: showEditor, preview: showPreview, review: showReview, files: showFiles)
    }

    /// Continues where the replaced window left off.
    func adopt(_ takeover: Takeover) {
        let panes = takeover.panes.effective
        if panes.editor { showEditor = true }
        if panes.preview { showPreview = true }
        showEditor = panes.editor
        showPreview = panes.preview
        showReview = panes.review
        showFiles = panes.files
        files.expanded.formUnion(takeover.expanded)
        files.filter = takeover.filter
        replacingWindow = takeover.replacing
    }

    /// Puts the new window where the replaced one was and closes that one.
    /// Closing may ask to save an untitled document, so the old window
    /// stays in front until it is gone; cancelling keeps both.
    static func take(placeOf old: NSWindow, by new: NSWindow) {
        if let tabs = old.tabbedWindows, tabs.count > 1 {
            old.addTabbedWindow(new, ordered: .above)
        } else {
            new.setFrame(old.frame, display: true)
        }
        new.orderFront(nil)
        old.makeKeyAndOrderFront(nil)
        let closing = NotificationCenter.default.notifications(named: NSWindow.willCloseNotification, object: old)
        Task { [weak new] in
            for await _ in closing {
                new?.makeKeyAndOrderFront(nil)
                break
            }
        }
        old.performClose(nil)
    }

    var hasUnfinishedReview: Bool { Self.isUnfinished(session.suggestions, running: isRunningAction) }

    /// Explains what replacing the document would lose.
    var reviewLossMessage: String {
        Self.reviewLossMessage(openSuggestions: session.suggestions.filter { Self.unfinished.contains($0.status) }.count,
                               runningAction: runningActionName,
                               documentName: fileURL?.lastPathComponent ?? "Untitled")
    }

    private static let unfinished: Set<Suggestion.Status> = [.open, .stale, .notFound, .ambiguous]

    static func isUnfinished(_ suggestions: [Suggestion], running: Bool) -> Bool {
        running || suggestions.contains { unfinished.contains($0.status) }
    }

    static func reviewLossMessage(openSuggestions: Int, runningAction: String?, documentName: String) -> String {
        var parts: [String] = []
        if let runningAction { parts.append("The running “\(runningAction)” action will be cancelled.") }
        if openSuggestions > 0 {
            parts.append("The \(openSuggestions) open suggestion\(openSuggestions == 1 ? "" : "s") for “\(documentName)” will be lost.")
        }
        return parts.joined(separator: " ")
    }
}

/// Tells the window model which `NSWindow` shows it.
struct WindowAccessor: NSViewRepresentable {
    let model: DocumentWindowModel

    func makeNSView(context: Context) -> NSView { AccessorView(model: model) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class AccessorView: NSView {
        weak var model: DocumentWindowModel?

        init(model: DocumentWindowModel) {
            self.model = model
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { model?.hostWindow = window }
        }
    }
}
