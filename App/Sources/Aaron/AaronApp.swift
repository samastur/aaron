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
        .commands {
            AppCommands(appModel: appModel)
        }

        Settings {
            SettingsView()
                .environment(appModel)
        }
    }
}
