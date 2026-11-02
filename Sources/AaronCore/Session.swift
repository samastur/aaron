import Foundation

/// The document windows of a session, saved so a normal start can reopen
/// them: each window's tabs in order, with their files and profiles.
public struct SavedSession: Codable, Equatable, Sendable {
    public var groups: [SavedTabGroup]
    /// The group that was in front.
    public var frontGroup: Int?

    public init(groups: [SavedTabGroup], frontGroup: Int?) {
        self.groups = groups
        self.frontGroup = frontGroup
    }

    /// Without files that no longer exist, and windows left without tabs.
    public func pruned(fileExists: (String) -> Bool) -> SavedSession {
        var kept: [SavedTabGroup] = []
        var front: Int?
        for (index, group) in groups.enumerated() {
            let selectedPath = group.tabs.indices.contains(group.selected) ? group.tabs[group.selected].path : nil
            let tabs = group.tabs.filter { fileExists($0.path) }
            guard !tabs.isEmpty else { continue }
            if index == frontGroup { front = kept.count }
            let selected = tabs.firstIndex { $0.path == selectedPath } ?? 0
            kept.append(SavedTabGroup(frame: group.frame, tabs: tabs, selected: selected))
        }
        return SavedSession(groups: kept, frontGroup: front)
    }
}

/// A window and the windows tabbed with it.
public struct SavedTabGroup: Codable, Equatable, Sendable {
    /// The window's frame, as `NSStringFromRect` writes it.
    public var frame: String
    public var tabs: [SavedTab]
    public var selected: Int

    public init(frame: String, tabs: [SavedTab], selected: Int) {
        self.frame = frame
        self.tabs = tabs
        self.selected = selected
    }
}

public struct SavedTab: Codable, Equatable, Sendable {
    public var path: String
    public var profile: String

    public init(path: String, profile: String) {
        self.path = path
        self.profile = profile
    }
}

/// How Aaron was started. Only a normal start reopens the last session and
/// saves its own; one asked to open a file or a profile does neither.
public enum LaunchKind: Equatable, Sendable {
    case normal
    case withRequest

    /// Passed by the `aaron` command when it starts Aaron, before it sends
    /// the files.
    public static let commandLineFlag = "--aaron-cli-launch"

    public static func decide(isDefaultLaunch: Bool, arguments: [String]) -> LaunchKind {
        isDefaultLaunch && !arguments.contains(commandLineFlag) ? .normal : .withRequest
    }
}
