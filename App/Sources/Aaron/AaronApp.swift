import AaronCore
import SwiftUI

@main
struct AaronApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private var appModel: AppModel { appDelegate.appModel }

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            DocumentWindow(document: file.$document, fileURL: file.fileURL)
                .environment(appModel)
        }
        .defaultSize(width: 1400, height: 860)
        .commands {
            AppCommands(appModel: appModel)
        }

        Window("Markdown Help", id: HelpView.windowID) {
            HelpView()
                .environment(appModel)
        }
        .defaultSize(width: 820, height: 900)

        Settings {
            SettingsView()
                .environment(appModel)
        }
    }
}

/// Owns the app model, so it exists before SwiftUI builds the scenes and
/// before Apple Events (such as `aaron://` requests) arrive.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appModel = AppModel.makeDefault()

    override init() {
        // Aaron reopens windows itself (see SessionRestore.swift); macOS's
        // own window restoration would bring back windows from a start with
        // a file too, and keeps untitled documents without asking.
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isDefault = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? false
        let opened = appModel.receivedOpenRequest || NSDocumentController.shared.documents.contains { $0.fileURL != nil }
        appModel.launchKind = LaunchKind.decide(isDefaultLaunch: isDefault, arguments: ProcessInfo.processInfo.arguments,
                                                openedSomething: opened)
        guard appModel.sessionToRestore() != nil else { return appModel.scheduleSessionSave() }
        Task {
            // Files and requests can arrive just after launch finishes.
            try? await Task.sleep(for: .milliseconds(300))
            if appModel.receivedOpenRequest || NSDocumentController.shared.documents.contains(where: { $0.fileURL != nil }) {
                appModel.launchKind = .withRequest
                return
            }
            guard let session = appModel.sessionToRestore() else { return }
            // Instead of the untitled window a start with nothing to open shows.
            let untitled = NSDocumentController.shared.documents.filter { $0.fileURL == nil && !$0.isDocumentEdited }
            await appModel.restore(session)
            for document in untitled { document.close() }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        appModel.stopSavingSession()
        return .terminateNow
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Before files given at launch are opened.
        DocumentReopening.enable()
        // Before launch finishes, so a request that starts the app is not missed.
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleGetURL(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: text) else { return }
        appModel.handle(url)
    }
}
