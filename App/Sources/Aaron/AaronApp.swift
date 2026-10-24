import AaronCore
import SwiftUI

@main
struct AaronApp: App {
    @State private var appModel = AppModel()

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
