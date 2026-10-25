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
}
