import Foundation

/// Finds files with a live Spotlight query limited to the root folder, so
/// files added, renamed or removed later are reported too.
@MainActor
public final class SpotlightFileSource: FileSource {
    private var query: NSMetadataQuery?
    /// Checks whether Spotlight indexes the root at all.
    private var probe: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []

    public init() {}

    public func start(root: URL, extensions: Set<String>, update: @escaping @MainActor (FileSourceEvent) -> Void) {
        stop()
        let query = NSMetadataQuery()
        query.searchScopes = [root]
        query.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: extensions.sorted().map {
            NSPredicate(format: "%K LIKE[c] %@", NSMetadataItemFSNameKey, "*.\($0)")
        })
        // Large roots report many results; deliver them in batches.
        query.notificationBatchingInterval = 0.5
        observe(.NSMetadataQueryGatheringProgress, of: query) { update(.progress(Self.urls(of: $0))) }
        observe(.NSMetadataQueryDidUpdate, of: query) { update(.updated(Self.urls(of: $0))) }
        observe(.NSMetadataQueryDidFinishGathering, of: query) { [weak self] query in
            let urls = Self.urls(of: query)
            if urls.isEmpty {
                self?.checkIndexed(root, update: update)
            } else {
                update(.finished(urls))
            }
        }
        self.query = query
        query.start()
    }

    public func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        query?.stop()
        query = nil
        probe?.stop()
        probe = nil
    }

    /// Nothing matched: tell an empty indexed folder from one Spotlight
    /// doesn't index, by asking for any item at all.
    private func checkIndexed(_ root: URL, update: @escaping @MainActor (FileSourceEvent) -> Void) {
        let probe = NSMetadataQuery()
        probe.searchScopes = [root]
        probe.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*")
        observe(.NSMetadataQueryDidFinishGathering, of: probe) { [weak self] probe in
            let indexed = probe.resultCount > 0
            probe.stop()
            self?.probe = nil
            update(indexed ? .finished([]) : .notIndexed)
        }
        self.probe = probe
        probe.start()
    }

    private func observe(_ name: Notification.Name, of query: NSMetadataQuery,
                         _ handler: @escaping @MainActor (NSMetadataQuery) -> Void) {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: query, queue: .main) { note in
            guard let query = note.object as? NSMetadataQuery else { return }
            nonisolated(unsafe) let sendable = query
            MainActor.assumeIsolated { handler(sendable) }
        })
    }

    private static func urls(of query: NSMetadataQuery) -> [URL] {
        query.disableUpdates()
        defer { query.enableUpdates() }
        return (0..<query.resultCount).compactMap { index in
            ((query.result(at: index) as? NSMetadataItem)?.value(forAttribute: NSMetadataItemPathKey) as? String)
                .map { URL(fileURLWithPath: $0) }
        }
    }
}
