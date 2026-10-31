import Foundation

/// A folder in the file panel's tree.
public struct FileFolder: Hashable, Sendable {
    public var url: URL
    public var name: String
    public var children: [FileNode]
    /// The iCloud Drive entry shown at the top of the tree.
    public var isICloudDrive: Bool

    public init(url: URL, name: String, children: [FileNode], isICloudDrive: Bool = false) {
        self.url = url
        self.name = name
        self.children = children
        self.isICloudDrive = isICloudDrive
    }
}

public enum FileNode: Identifiable, Hashable, Sendable {
    case folder(FileFolder)
    case file(URL)

    public var id: URL { url }

    public var url: URL {
        switch self {
        case .folder(let folder): folder.url
        case .file(let url): url
        }
    }

    public var name: String {
        switch self {
        case .folder(let folder): folder.name
        case .file(let url): url.lastPathComponent
        }
    }

    public var children: [FileNode]? {
        if case .folder(let folder) = self { return folder.children }
        return nil
    }

    /// Folders first, then files, each in Finder's order.
    static func sorted(_ nodes: [FileNode]) -> [FileNode] {
        nodes.sorted { a, b in
            let aFolder = a.children != nil, bFolder = b.children != nil
            if aFolder != bFolder { return aFolder }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
}

/// The tree and the files it shows.
public struct FileTree: Sendable {
    public var nodes: [FileNode]
    /// The files that are in the tree: not hidden, ignored or outside the root.
    public var files: [URL]
}

/// Remembers which folders macOS hides, across tree builds; safe to use
/// from any thread.
public final class HiddenFolderCache: @unchecked Sendable {
    private let lock = NSLock()
    private var hidden: [String: Bool] = [:]

    public init() {}

    public func isHidden(_ folder: URL) -> Bool {
        if let known = lock.withLock({ hidden[folder.path] }) { return known }
        let value = FileTreeBuilder.isHiddenOnDisk(folder)
        lock.withLock { hidden[folder.path] = value }
        return value
    }
}

/// Builds the tree of folders leading to the given files: a folder exists
/// only when a file is somewhere below it.
public struct FileTreeBuilder: Sendable {
    public static let iCloudDriveName = "iCloud Drive"

    let root: URL
    let ignoredFolders: Set<String>
    let iCloudDrive: URL?
    let isHidden: @Sendable (URL) -> Bool

    public init(root: URL, ignoredFolders: [String], iCloudDrive: URL?, isHidden: @escaping @Sendable (URL) -> Bool) {
        self.root = root.standardizedFileURL
        self.ignoredFolders = Set(ignoredFolders)
        self.iCloudDrive = iCloudDrive?.standardizedFileURL
        self.isHidden = isHidden
    }

    /// The iCloud Drive folder on this Mac.
    public static var defaultICloudDrive: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    /// Asks the file system whether macOS hides a folder, such as `~/Library`.
    public static func isHiddenOnDisk(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isHiddenKey]).isHidden) ?? false
    }

    private final class Folder {
        var folders: [String: Folder] = [:]
        var files: [URL] = []
    }

    public func build(_ files: [URL]) -> [FileNode] { buildTree(files).nodes }

    public func buildTree(_ files: [URL]) -> FileTree {
        let rootComponents = root.pathComponents
        let iCloudComponents = iCloudDrive.map(\.pathComponents)
        // iCloud Drive is shown on its own when it is below the root.
        let iCloudBelowRoot = iCloudComponents.map {
            $0.count > rootComponents.count && Array($0.prefix(rootComponents.count)) == rootComponents
        } ?? false
        let top = Folder()
        let iCloud = Folder()
        var hiddenCache: [String: Bool] = [:]
        var visibleFiles: [URL] = []

        for file in files {
            let components = file.standardizedFileURL.pathComponents
            guard components.count > rootComponents.count,
                  Array(components.prefix(rootComponents.count)) == rootComponents else { continue }
            var base = rootComponents.count
            var folder = top
            if iCloudBelowRoot, let iCloudComponents, components.count > iCloudComponents.count,
               Array(components.prefix(iCloudComponents.count)) == iCloudComponents {
                base = iCloudComponents.count
                folder = iCloud
            }
            let relative = components[base...]
            guard !relative.contains(where: { $0.hasPrefix(".") || ignoredFolders.contains($0) }) else { continue }
            var path = NSString.path(withComponents: Array(components.prefix(base)))
            var visible = true
            for name in relative.dropLast() {
                path = (path as NSString).appendingPathComponent(name)
                let hidden = hiddenCache[path] ?? {
                    let value = isHidden(URL(fileURLWithPath: path, isDirectory: true))
                    hiddenCache[path] = value
                    return value
                }()
                if hidden { visible = false; break }
                if let next = folder.folders[name] {
                    folder = next
                } else {
                    let next = Folder()
                    folder.folders[name] = next
                    folder = next
                }
            }
            if visible {
                folder.files.append(file)
                visibleFiles.append(file)
            }
        }

        func nodes(_ folder: Folder, at url: URL) -> [FileNode] {
            let folders = folder.folders.map { name, child -> FileNode in
                let childURL = url.appendingPathComponent(name, isDirectory: true)
                return .folder(FileFolder(url: childURL, name: name, children: nodes(child, at: childURL)))
            }.filter { $0.children?.isEmpty == false }
            return FileNode.sorted(folders + folder.files.map { .file($0) })
        }

        var result = nodes(top, at: root)
        if let iCloudDrive, iCloudBelowRoot {
            let children = nodes(iCloud, at: iCloudDrive)
            if !children.isEmpty {
                result.insert(.folder(FileFolder(url: iCloudDrive, name: Self.iCloudDriveName,
                                                 children: children, isICloudDrive: true)), at: 0)
            }
        }
        return FileTree(nodes: result, files: visibleFiles)
    }
}

/// A file found by the panel's filter.
public struct FileMatch: Identifiable, Hashable, Sendable {
    public var url: URL
    public var name: String
    /// The folder, relative to the root; empty for files directly in it.
    public var folder: String

    public var id: URL { url }
}

/// The files whose name contains the query, ignoring case and diacritics.
public func filterFiles(_ files: [URL], root: URL, query: String) -> [FileMatch] {
    let query = query.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return [] }
    let rootComponents = root.standardizedFileURL.pathComponents
    return files.compactMap { file -> FileMatch? in
        let name = file.lastPathComponent
        guard name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil else { return nil }
        let folder = Array(file.standardizedFileURL.deletingLastPathComponent().pathComponents.dropFirst(rootComponents.count))
        return FileMatch(url: file, name: name, folder: folder.joined(separator: "/"))
    }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}
