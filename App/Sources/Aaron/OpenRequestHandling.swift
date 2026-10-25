import AaronCore
import Foundation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Aaron", category: "open")

extension AppModel {
    /// An `aaron://open` request from the `aaron` command. Requests without
    /// the command's token are ignored: a web page or another app must not
    /// be able to open files and so run a profile's commands on them.
    func handle(_ url: URL) {
        guard let request = OpenRequest(url: url) else {
            logger.warning("Ignored malformed request \(url.absoluteString, privacy: .public)")
            return
        }
        guard let token = try? store.cliToken(), request.token == token else {
            logger.warning("Ignored request with a wrong token")
            return
        }
        var profile: String?
        if let name = request.profile {
            profile = profileNames.first { $0.caseInsensitiveCompare(name) == .orderedSame }
            if profile == nil {
                configurationError = "There is no profile named “\(name)”; the default profile is used instead."
            }
        }
        for path in request.paths {
            let file = URL(fileURLWithPath: path).standardizedFileURL
            if let profile {
                if let window = windows.first(where: { $0.fileURL.map { Self.isSameFile($0, file) } ?? false }) {
                    window.profileName = profile
                } else {
                    pendingProfiles.removeAll { Self.isSameFile($0.file, file) }
                    pendingProfiles.append((file, profile))
                }
            }
            openDocument(file) { [weak self] error in
                // Don't let a later, unrelated open pick up the profile.
                if error != nil { self?.pendingProfiles.removeAll { Self.isSameFile($0.file, file) } }
            }
        }
    }

    /// The profile the `aaron` command asked for when opening this file;
    /// returned once.
    func pendingProfile(for fileURL: URL?) -> String? {
        guard let fileURL,
              let index = pendingProfiles.firstIndex(where: { Self.isSameFile($0.file, fileURL) }) else { return nil }
        return pendingProfiles.remove(at: index).profile
    }

    /// Whether two URLs name the same file, also when reached through a
    /// symlink or spelled with different case.
    static func isSameFile(_ a: URL, _ b: URL) -> Bool {
        if a.standardizedFileURL == b.standardizedFileURL { return true }
        func identifier(_ url: URL) -> (any NSObjectProtocol)? {
            try? URL(fileURLWithPath: url.path).resourceValues(forKeys: [.fileResourceIdentifierKey])
                .fileResourceIdentifier
        }
        guard let first = identifier(a), let second = identifier(b) else { return false }
        return first.isEqual(second)
    }
}
