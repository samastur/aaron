import Foundation

/// Reads one folder at a time, for browsing where Spotlight doesn't reach.
public struct FolderReader: Sendable {
    public init() {}

    /// The folder's subfolders and files with one of the extensions;
    /// hidden items, packages and ignored folders are left out. Subfolders
    /// have no children until they are read themselves.
    public func contents(of folder: URL, extensions: Set<String>, ignoredFolders: [String]) -> [FileNode] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isHiddenKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        let ignored = Set(ignoredFolders)
        let nodes = items.compactMap { item -> FileNode? in
            let values = try? item.resourceValues(forKeys: Set(keys))
            if values?.isHidden == true { return nil }
            if values?.isDirectory == true {
                guard values?.isPackage != true, !ignored.contains(item.lastPathComponent) else { return nil }
                return .folder(FileFolder(url: item, name: item.lastPathComponent, children: []))
            }
            return extensions.contains(item.pathExtension.lowercased()) ? .file(item) : nil
        }
        return FileNode.sorted(nodes)
    }
}
