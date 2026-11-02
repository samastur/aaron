import AaronCore
import AppKit

extension AppModel {
    /// The open document windows, front to back, grouped by tab group.
    /// Untitled documents aren't part of it.
    func currentSession() -> SavedSession { currentSession(windows: NSApp.orderedWindows) }

    /// `ordered`: windows front to back. Document windows missing from it
    /// (minimized, or Aaron hidden) are saved after them.
    func currentSession(windows ordered: [NSWindow]) -> SavedSession {
        var groups: [SavedTabGroup] = []
        var seen: Set<ObjectIdentifier> = []
        let documentWindows = windows.compactMap(\.hostWindow)
        let candidates = ordered.filter { window in documentWindows.contains { $0 === window } }
            + documentWindows.filter { window in !ordered.contains { $0 === window } }
        for window in candidates {
            let tabs = window.tabbedWindows ?? [window]
            guard !seen.contains(ObjectIdentifier(tabs[0])) else { continue }
            seen.insert(ObjectIdentifier(tabs[0]))
            let saved = tabs.compactMap { tab -> (NSWindow, SavedTab)? in
                guard let model = windows.first(where: { $0.hostWindow === tab }), let url = model.fileURL else { return nil }
                return (tab, SavedTab(path: url.path, profile: model.profileName))
            }
            guard !saved.isEmpty else { continue }
            let selectedWindow = window.tabGroup?.selectedWindow ?? window
            groups.append(SavedTabGroup(frame: NSStringFromRect(window.frame), tabs: saved.map(\.1),
                                        selected: saved.firstIndex { $0.0 === selectedWindow } ?? 0))
        }
        return SavedSession(groups: groups, frontGroup: groups.isEmpty ? nil : 0)
    }

    /// Saves the session soon, if this session started normally.
    func scheduleSessionSave() {
        guard launchKind == .normal, !sessionSavingStopped else { return }
        sessionSaveTask?.cancel()
        sessionSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.saveSessionNow()
        }
    }

    func saveSessionNow() {
        guard launchKind == .normal, !sessionSavingStopped else { return }
        sessionSaveTask?.cancel()
        try? store.saveSession(currentSession())
    }

    /// Saves the session one last time; windows closing while Aaron quits
    /// must not remove themselves from it.
    func stopSavingSession() {
        saveSessionNow()
        sessionSavingStopped = true
    }

    /// The session a normal start reopens, if any.
    func sessionToRestore() -> SavedSession? {
        guard launchKind == .normal, store.reopenWindows(), let session = store.loadSession() else { return nil }
        let pruned = session.pruned { FileManager.default.fileExists(atPath: $0) }
        return pruned.groups.isEmpty ? nil : pruned
    }

    /// Closes the untitled documents a start shows, unless typed in since.
    static func closeUntouched(_ documents: [NSDocument]) {
        for document in documents where !document.isDocumentEdited { document.close() }
    }

    /// Opens the session's files with their profiles, as windows and tabs.
    func restore(_ session: SavedSession) async {
        isRestoringSession = true
        defer {
            isRestoringSession = false
            scheduleSessionSave()
        }
        var groupWindows: [NSWindow] = []
        for group in session.groups {
            var previous: NSWindow?
            var tabs: [NSWindow] = []
            for tab in group.tabs {
                guard let window = await open(URL(fileURLWithPath: tab.path), profile: tab.profile) else { continue }
                if let previous {
                    previous.addTabbedWindow(window, ordered: .above)
                } else {
                    window.setFrame(NSRectFromString(group.frame), display: true)
                }
                previous = window
                tabs.append(window)
            }
            if tabs.indices.contains(group.selected) { tabs[group.selected].makeKeyAndOrderFront(nil) }
            if let first = tabs.first { groupWindows.append(first.tabGroup?.selectedWindow ?? first) }
        }
        if let front = session.frontGroup, groupWindows.indices.contains(front) {
            groupWindows[front].makeKeyAndOrderFront(nil)
        }
    }

    /// Opens a file with a profile and waits for its window.
    private func open(_ file: URL, profile: String) async -> NSWindow? {
        let before = Set(windows.map(ObjectIdentifier.init))
        openDocument(file, profile: profile)
        for _ in 0..<100 {
            if let model = windows.first(where: { !before.contains(ObjectIdentifier($0))
                && $0.fileURL.map { Self.isSameFile($0, file) } == true }),
               let window = model.hostWindow {
                return window
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }
}
