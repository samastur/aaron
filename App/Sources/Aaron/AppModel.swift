import AaronCore
import AaronPelican
import AppKit
import Observation

/// App-wide state: the configuration profiles and services shared by all
/// windows.
@MainActor
@Observable
final class AppModel {
    let store: ProfileStore
    let tagProvider = TagProvider()

    private(set) var profileNames: [String] = []
    private(set) var defaultProfileName = ProfileStore.initialProfileName
    private var profiles: [String: Configuration] = [:]

    /// The profile the Settings window edits.
    var settingsProfileName = ProfileStore.initialProfileName
    /// The profile of the document window that was last in front.
    var frontProfileName: String?

    /// What the Markdown Help window shows: chosen when it is opened.
    var helpRequest = HelpRequest(isPelican: false, fileURL: nil, profileName: ProfileStore.initialProfileName)

    /// Set when a profile could not be read or written.
    var configurationError: String?
    /// Profiles whose file could not be parsed; they are not overwritten
    /// until reloaded successfully, so hand edits are not lost.
    private var unreadable: Set<String> = []

    @ObservationIgnored private var saveTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    init(store: ProfileStore) {
        self.store = store
        loadProfiles()
        settingsProfileName = defaultProfileName
        // Don't lose edits made just before quitting to the save delay.
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveIfPending() }
        }
    }

    /// The model for the running app: the support folder named in
    /// Info.plist (different for Debug builds), or `AARON_SUPPORT_DIR`.
    static func makeDefault() -> AppModel {
        let folder = Bundle.main.object(forInfoDictionaryKey: "AaronSupportFolderName") as? String ?? "Aaron"
        return AppModel(store: ProfileStore(directory: ProfileStore.defaultDirectory(folderName: folder)))
    }

    // MARK: - Configurations

    /// The named profile's configuration; the default profile's for an
    /// unknown name.
    func configuration(for name: String) -> Configuration {
        profiles[name] ?? profiles[defaultProfileName] ?? .default
    }

    /// Changes a profile; it is saved shortly after.
    func setConfiguration(_ configuration: Configuration, for name: String) {
        guard let old = profiles[name], old != configuration else { return }
        profiles[name] = configuration
        scheduleSave(name)
    }

    /// The profile selected in Settings, for its bindings.
    var settingsConfiguration: Configuration {
        get { configuration(for: settingsProfileName) }
        set { setConfiguration(newValue, for: settingsProfileName) }
    }

    func profileURL(_ name: String) -> URL { store.url(for: name) }

    // MARK: - Managing profiles

    /// Adds a copy of a profile, named "<name> copy" (or "copy 2", …).
    @discardableResult
    func addProfile(copying source: String) throws -> String {
        var name = "\(source) copy"
        var number = 2
        while ProfileStore.validationError(for: name, existing: profileNames) != nil {
            name = "\(source) copy \(number)"
            number += 1
        }
        let configuration = configuration(for: source)
        try store.save(configuration, as: name)
        profiles[name] = configuration
        profileNames = store.names()
        return name
    }

    func renameProfile(_ old: String, to new: String) throws {
        guard old != new else { return }
        flushSave(old)
        try store.rename(old, to: new)
        profiles[new] = profiles.removeValue(forKey: old)
        if unreadable.remove(old) != nil { unreadable.insert(new) }
        profileNames = store.names()
        defaultProfileName = store.defaultProfileName()
        if settingsProfileName == old { settingsProfileName = new }
        if frontProfileName == old { frontProfileName = new }
        if helpRequest.profileName == old { helpRequest.profileName = new }
        profileRenamed(old, to: new)
    }

    func deleteProfile(_ name: String) throws {
        try store.delete(name)
        saveTasks.removeValue(forKey: name)?.cancel()
        let old = profiles.removeValue(forKey: name)
        unreadable.remove(name)
        profileNames = store.names()
        if settingsProfileName == name { settingsProfileName = defaultProfileName }
        if frontProfileName == name { frontProfileName = nil }
        profileDeleted(name, configuration: old ?? .default)
    }

    func setDefaultProfile(_ name: String) throws {
        try store.setDefaultProfile(name)
        defaultProfileName = name
    }

    func importProfile(from source: URL, named name: String) throws {
        try store.importProfile(from: source, as: name)
        profiles[name] = try store.load(name)
        profileNames = store.names()
    }

    /// Reads every profile from disk again, e.g. after editing files by hand.
    func reloadProfiles() {
        for task in saveTasks.values { task.cancel() }
        saveTasks = [:]
        let old = profiles
        loadProfiles()
        if !profileNames.contains(settingsProfileName) { settingsProfileName = defaultProfileName }
        profilesReloaded(from: old)
    }

    func revealProfilesFolder() {
        let url = store.url(for: settingsProfileName)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([store.profilesDirectory])
        }
    }

    private func loadProfiles() {
        var errors: [String] = []
        do {
            try store.prepare()
        } catch {
            errors.append("Could not set up the profiles folder \(store.profilesDirectory.path): \(error.localizedDescription)")
        }
        var loaded: [String: Configuration] = [:]
        unreadable = []
        for name in store.names() {
            do {
                loaded[name] = try store.load(name)
            } catch {
                loaded[name] = .default
                unreadable.insert(name)
                errors.append("Could not read profile “\(name)” (\(store.url(for: name).path)): "
                              + "\(error.localizedDescription). It uses default settings and will not be saved "
                              + "until the file is fixed and reloaded.")
            }
        }
        if loaded.isEmpty { loaded[ProfileStore.initialProfileName] = .default }
        profiles = loaded
        profileNames = loaded.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        defaultProfileName = store.defaultProfileName()
        if profiles[defaultProfileName] == nil { defaultProfileName = profileNames[0] }
        configurationError = errors.isEmpty ? nil : errors.joined(separator: "\n\n")
    }

    // MARK: - Saving

    func saveIfPending() {
        for name in Array(saveTasks.keys) { flushSave(name) }
    }

    private func flushSave(_ name: String) {
        guard let task = saveTasks.removeValue(forKey: name) else { return }
        task.cancel()
        saveNow(name)
    }

    private func scheduleSave(_ name: String) {
        saveTasks[name]?.cancel()
        saveTasks[name] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveTasks[name] = nil
            self?.saveNow(name)
        }
    }

    private func saveNow(_ name: String) {
        // Don't overwrite a file we failed to parse; the user may be fixing it.
        guard !unreadable.contains(name), let configuration = profiles[name] else { return }
        do {
            try store.save(configuration, as: name)
        } catch {
            configurationError = "Could not save profile “\(name)”: \(error.localizedDescription)"
        }
    }

    // MARK: - Windows (filled in with per-window profiles)

    private func profileRenamed(_ old: String, to new: String) {}
    private func profileDeleted(_ name: String, configuration: Configuration) {}
    private func profilesReloaded(from old: [String: Configuration]) {}
}
