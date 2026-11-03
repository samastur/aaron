import AppKit
import SwiftUI

/// A new untitled document waiting for its window: the profile it opens
/// with and the window it becomes a tab of.
struct NewTab {
    var profile: String
    weak var parent: NSWindow?
    /// An untitled window that doesn't appear soon after (e.g. the document
    /// couldn't be created) must not hijack a later ⌘N.
    var created = Date()

    static let lifetime: TimeInterval = 10
}

/// ⌘1–⌘8 choose tabs 1–8 and ⌘9 the last, as in browsers.
enum TabKeys {
    static func index(forKey key: Int, tabCount: Int) -> Int? {
        guard tabCount > 1 else { return nil }
        if key == 9 { return tabCount - 1 }
        return (1...8).contains(key) && key <= tabCount ? key - 1 : nil
    }

    /// Chooses a tab of the key window.
    @MainActor static func select(key: Int) {
        guard let window = NSApp.keyWindow, let tabs = window.tabbedWindows,
              let index = index(forKey: key, tabCount: tabs.count) else { return }
        tabs[index].makeKeyAndOrderFront(nil)
    }
}

extension AppModel {
    /// File ▸ New Tab: an untitled document in a new tab of the window, with
    /// its profile; without a window, a new window with the default profile.
    func newTab(from window: DocumentWindowModel?) {
        newTab(profile: window?.profileName ?? defaultProfileName, parent: window?.hostWindow)
    }

    func newTab(profile: String, parent: NSWindow?) {
        pendingNewTabs.append(NewTab(profile: profile, parent: parent))
        newDocument()
    }

    /// The new tab waiting for an untitled window; returned once.
    func takeNewTab(now: Date = Date()) -> NewTab? {
        pendingNewTabs.removeAll { now.timeIntervalSince($0.created) > NewTab.lifetime }
        return pendingNewTabs.isEmpty ? nil : pendingNewTabs.removeFirst()
    }
}

extension DocumentWindowModel {
    /// Joins the window it was opened as a tab of.
    static func join(_ window: NSWindow, asTabOf parent: NSWindow) {
        guard parent !== window, parent.isVisible else { return }
        parent.addTabbedWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
    }
}
