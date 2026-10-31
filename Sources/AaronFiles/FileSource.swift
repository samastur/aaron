import Foundation

/// What a file source reports. Every case but `notIndexed` carries the
/// full current list of files.
public enum FileSourceEvent: Equatable, Sendable {
    /// Results found so far, while the first search runs.
    case progress([URL])
    /// The first search is complete.
    case finished([URL])
    /// Files were added, renamed or removed afterwards.
    case updated([URL])
    /// The root isn't searchable, e.g. a drive Spotlight doesn't index.
    case notIndexed
}

/// Finds the files with the given extensions below a root folder.
@MainActor
public protocol FileSource: AnyObject {
    func start(root: URL, extensions: Set<String>, update: @escaping @MainActor (FileSourceEvent) -> Void)
    func stop()
}
