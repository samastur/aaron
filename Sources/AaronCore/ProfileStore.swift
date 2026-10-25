import Foundation

public enum ProfileError: LocalizedError, Equatable {
    case invalidName(String)
    case cannotDeleteDefault
    case cannotDeleteLast
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let reason): reason
        case .cannotDeleteDefault: "The default profile can't be deleted. Make another profile the default first."
        case .cannotDeleteLast: "The last profile can't be deleted."
        case .notFound(let name): "There is no profile named “\(name)”."
        }
    }
}

/// The support folder: one configuration file per profile in `Profiles/`,
/// the default profile's name in `profiles.json`, and the token the `aaron`
/// command uses to talk to the app.
public struct ProfileStore: Sendable {
    public static let environmentKey = "AARON_SUPPORT_DIR"
    public static let initialProfileName = "Default"

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func defaultDirectory(environment: [String: String] = ProcessInfo.processInfo.environment,
                                        folderName: String) -> URL {
        if let override = environment[environmentKey], !override.isEmpty {
            return URL(fileURLWithPath: PathExpansion.expand(override))
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent(folderName)
    }

    public var profilesDirectory: URL { directory.appendingPathComponent("Profiles") }
    var settingsURL: URL { directory.appendingPathComponent("profiles.json") }
    var legacyURL: URL { directory.appendingPathComponent("config.json") }
    var tokenURL: URL { directory.appendingPathComponent("cli-token") }

    public func url(for name: String) -> URL {
        profilesDirectory.appendingPathComponent(name + ".json")
    }

    /// Creates the profiles folder on first use, moving an old single
    /// `config.json` into the first profile, and makes sure at least one
    /// profile exists.
    public func prepare() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: profilesDirectory.path) {
            try fm.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
            if fm.fileExists(atPath: legacyURL.path) {
                try fm.copyItem(at: legacyURL, to: url(for: Self.initialProfileName))
                let migrated = directory.appendingPathComponent("config.json.migrated")
                try? fm.removeItem(at: migrated)
                try fm.moveItem(at: legacyURL, to: migrated)
            }
        }
        if names().isEmpty {
            try save(.default, as: Self.initialProfileName)
        }
        // Record the default, so adding a profile that sorts first doesn't
        // silently make it the default.
        if storedDefaultProfileName() == nil {
            try setDefaultProfile(defaultProfileName())
        }
    }

    public func names() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: profilesDirectory.path)) ?? []
        return files.filter { $0.hasSuffix(".json") && !$0.hasPrefix(".") }
            .map { String($0.dropLast(5)) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public func load(_ name: String) throws -> Configuration {
        let url = url(for: name)
        guard FileManager.default.fileExists(atPath: url.path) else { throw ProfileError.notFound(name) }
        return try ConfigurationStore.load(from: url)
    }

    public func save(_ configuration: Configuration, as name: String) throws {
        try ConfigurationStore.save(configuration, to: url(for: name))
    }

    public func rename(_ old: String, to new: String) throws {
        if let error = Self.validationError(for: new, existing: names(), ignoring: old) {
            throw ProfileError.invalidName(error)
        }
        guard names().contains(old) else { throw ProfileError.notFound(old) }
        let wasDefault = defaultProfileName() == old
        // Via a temporary name, so a change of case works on a
        // case-insensitive file system.
        let temporary = profilesDirectory.appendingPathComponent(".rename-\(UUID().uuidString)")
        try FileManager.default.moveItem(at: url(for: old), to: temporary)
        try FileManager.default.moveItem(at: temporary, to: url(for: new))
        if wasDefault { try setDefaultProfile(new) }
    }

    public func delete(_ name: String) throws {
        let all = names()
        guard all.contains(name) else { throw ProfileError.notFound(name) }
        guard all.count > 1 else { throw ProfileError.cannotDeleteLast }
        guard defaultProfileName() != name else { throw ProfileError.cannotDeleteDefault }
        try FileManager.default.removeItem(at: url(for: name))
    }

    public func defaultProfileName() -> String {
        storedDefaultProfileName() ?? names().first ?? Self.initialProfileName
    }

    /// The default named in `profiles.json`, if that profile exists.
    private func storedDefaultProfileName() -> String? {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(ProfileSettings.self, from: data),
              let name = settings.defaultProfile, names().contains(name) else { return nil }
        return name
    }

    public func setDefaultProfile(_ name: String) throws {
        guard names().contains(name) else { throw ProfileError.notFound(name) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(ProfileSettings(defaultProfile: name)).write(to: settingsURL, options: .atomic)
    }

    /// Adds a profile from a configuration file, which may contain only
    /// some settings.
    public func importProfile(from source: URL, as name: String) throws {
        if let error = Self.validationError(for: name, existing: names()) {
            throw ProfileError.invalidName(error)
        }
        try save(try ConfigurationStore.load(from: source), as: name)
    }

    /// A random secret shared with the `aaron` command, readable only by
    /// the user, so other apps and web pages can't open files with a profile.
    public func cliToken() throws -> String {
        if let token = try? String(contentsOf: tokenURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), token.count == 32 {
            return token
        }
        var generator = SystemRandomNumberGenerator()
        let token = (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255, using: &generator)) }.joined()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: tokenURL.path, contents: Data(token.utf8),
                                             attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: tokenURL.path])
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenURL.path)
        return token
    }

    /// Why `name` can't be used for a profile, or nil when it can.
    public static func validationError(for name: String, existing: [String], ignoring: String? = nil) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "A profile needs a name." }
        if trimmed != name { return "A profile name can't start or end with spaces." }
        if name.contains("/") || name.contains(":") { return "A profile name can't contain “/” or “:”." }
        if name.hasPrefix(".") { return "A profile name can't start with “.”." }
        let others = existing.filter { $0 != ignoring }
        if others.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            return "There already is a profile named “\(name)”."
        }
        return nil
    }
}

private struct ProfileSettings: Codable {
    var defaultProfile: String?
}
