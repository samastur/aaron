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

    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(configurationURL: URL = ConfigurationStore.defaultURL()) {
        self.configurationURL = configurationURL
        do {
            configuration = try ConfigurationStore.load(from: configurationURL)
        } catch {
            configuration = .default
            configurationError = "Could not read \(configurationURL.path): \(error.localizedDescription). "
                + "Using default settings; they will not be saved until the file is fixed or reloaded."
        }
    }

    func reloadConfiguration() {
        do {
            let loaded = try ConfigurationStore.load(from: configurationURL)
            saveTask?.cancel()
            configuration = loaded
            saveTask?.cancel()
            configurationError = nil
        } catch {
            configurationError = "Could not read \(configurationURL.path): \(error.localizedDescription)"
        }
    }

    func revealConfigurationFile() {
        if !FileManager.default.fileExists(atPath: configurationURL.path) {
            saveNow()
        }
        NSWorkspace.shared.activateFileViewerSelecting([configurationURL])
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        // Don't overwrite a file we failed to parse; the user may be fixing it.
        guard configurationError == nil || !FileManager.default.fileExists(atPath: configurationURL.path) else { return }
        do {
            try ConfigurationStore.save(configuration, to: configurationURL)
        } catch {
            configurationError = "Could not save settings: \(error.localizedDescription)"
        }
    }
}
