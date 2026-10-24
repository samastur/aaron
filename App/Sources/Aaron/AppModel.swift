import AaronCore
import AaronPelican
import AppKit
import Observation

/// App-wide state: the configuration and services shared by all windows.
@MainActor
@Observable
final class AppModel {
    let configurationURL: URL
    let tagProvider = TagProvider()

    /// Edits are saved to disk shortly after they happen.
    var configuration: Configuration {
        didSet { if configuration != oldValue { scheduleSave() } }
    }

    /// Set when the configuration file could not be read or written.
    var configurationError: String?
    /// The file on disk could not be parsed; it is not overwritten until it
    /// has been reloaded successfully, so hand edits are not lost.
    private var fileIsUnreadable = false

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    init(configurationURL: URL = ConfigurationStore.defaultURL()) {
        self.configurationURL = configurationURL
        do {
            configuration = try ConfigurationStore.load(from: configurationURL)
        } catch {
            configuration = .default
            fileIsUnreadable = true
            configurationError = "Could not read \(configurationURL.path): \(error.localizedDescription). "
                + "Using default settings; they will not be saved until the file is fixed or reloaded."
        }
        // Don't lose edits made just before quitting to the save delay.
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveIfPending() }
        }
    }

    func saveIfPending() {
        guard let task = saveTask else { return }
        task.cancel()
        saveTask = nil
        saveNow()
    }

    func reloadConfiguration() {
        do {
            let loaded = try ConfigurationStore.load(from: configurationURL)
            configuration = loaded
            // Just read from disk; no need to write it back.
            saveTask?.cancel()
            configurationError = nil
            fileIsUnreadable = false
        } catch {
            fileIsUnreadable = true
            configurationError = "Could not read \(configurationURL.path): \(error.localizedDescription)"
        }
    }

    func revealConfigurationFile() {
        if !FileManager.default.fileExists(atPath: configurationURL.path) {
            fileIsUnreadable = false
            saveNow()
        }
        NSWorkspace.shared.activateFileViewerSelecting([configurationURL])
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveTask = nil
            self?.saveNow()
        }
    }

    func saveNow() {
        // Don't overwrite a file we failed to parse; the user may be fixing it.
        guard !fileIsUnreadable else { return }
        do {
            try ConfigurationStore.save(configuration, to: configurationURL)
        } catch {
            configurationError = "Could not save settings: \(error.localizedDescription)"
        }
    }
}
