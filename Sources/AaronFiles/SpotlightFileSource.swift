import Foundation

/// Finds files with a live Spotlight query limited to the root folder, so
/// files added, renamed or removed later are reported too.
@MainActor
public final class SpotlightFileSource: FileSource {
    private var query: NSMetadataQuery?
    /// Checks whether Spotlight indexes the root at all.
    private var probe: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    /// Results are read here, not on the main thread: a large root has
    /// tens of thousands of them.
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    public init() {}

    isolated deinit { stop() }

    public func start(root: URL, extensions: Set<String>, update: @escaping @MainActor (FileSourceEvent) -> Void) {
        stop()
        let query = NSMetadataQuery()
        query.searchScopes = [root]
        query.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: extensions.sorted().map {
            NSPredicate(format: "%K LIKE[c] %@", NSMetadataItemFSNameKey, "*.\($0)")
        })
        // Large roots report many results; deliver them in batches.
        query.notificationBatchingInterval = 0.5
        query.operationQueue = queue
        observe(.NSMetadataQueryGatheringProgress, of: query) { .progress($0) } handle: { update($0) }
        observe(.NSMetadataQueryDidUpdate, of: query) { .updated($0) } handle: { update($0) }
        observe(.NSMetadataQueryDidFinishGathering, of: query) { .finished($0) } handle: { [weak self] event in
            if event == .finished([]) {
                self?.checkIndexed(root, update: update)
            } else {
                update(event)
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
        probe.operationQueue = queue
        observe(.NSMetadataQueryDidFinishGathering, of: probe) { urls in
            urls.isEmpty ? .notIndexed : .finished([])
        } handle: { [weak self] event in
            self?.probe?.stop()
            self?.probe = nil
            update(event)
        }
        self.probe = probe
        probe.start()
    }

    /// Reads the results on the query's queue, then hands the event to the
    /// main thread in order.
    private func observe(_ name: Notification.Name, of query: NSMetadataQuery,
                         event: @escaping @Sendable ([URL]) -> FileSourceEvent,
                         handle: @escaping @MainActor (FileSourceEvent) -> Void) {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: query, queue: queue) { note in
            guard let query = note.object as? NSMetadataQuery else { return }
            let result = event(Self.urls(of: query))
            DispatchQueue.main.async { MainActor.assumeIsolated { handle(result) } }
        })
    }

    private nonisolated static func urls(of query: NSMetadataQuery) -> [URL] {
        query.disableUpdates()
        defer { query.enableUpdates() }
        return (0..<query.resultCount).compactMap { index in
            ((query.result(at: index) as? NSMetadataItem)?.value(forAttribute: NSMetadataItemPathKey) as? String)
                .map { URL(fileURLWithPath: $0) }
        }
    }
}
