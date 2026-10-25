import AaronCore
import AaronPelican
import SwiftUI

struct AppCommands: Commands {
    let appModel: AppModel
    @FocusedValue(\.windowModel) private var window

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Button("Install Command Line Tool…") {
                Task { await CommandLineToolInstall.run() }
            }
        }

        CommandGroup(after: .newItem) {
            NewPelicanPostButton(template: appModel.configuration(for: appModel.defaultProfileName).pelican.newPostTemplate)
        }

        CommandGroup(after: .toolbar) {
            Button(window?.showPreview == true ? "Hide Preview" : "Show Preview") {
                window?.showPreview.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
            .disabled(window == nil)

            Button("Refresh Preview") { window?.refreshPreview(immediately: true) }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(window?.showPreview != true)

            Button(window?.showReview == true ? "Hide Review" : "Show Review") {
                window?.showReview.toggle()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(window == nil)

            Menu("Profile") {
                ForEach(appModel.profileNames, id: \.self) { name in
                    Toggle(name, isOn: Binding(
                        get: { window?.profileName == name },
                        set: { if $0 { window?.profileName = name } }))
                }
            }
            .disabled(window == nil)
            Divider()
        }

        CommandGroup(after: .textEditing) {
            Divider()
            Button("Refresh Pelican Tags") { window?.loadTagsIfNeeded(refresh: true) }
                .disabled(window?.isPelican != true)
        }

        CommandGroup(replacing: .help) {
            MarkdownHelpButton(appModel: appModel, window: window)
        }

        CommandMenu("Review") {
            let actions = (window?.configuration ?? appModel.configuration(for: appModel.defaultProfileName)).aiActions
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                actionButton(action, index: index)
            }
            if actions.isEmpty {
                Text("No AI actions configured")
            }
            Button("Cancel AI Action") { window?.cancelAction() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(window?.isRunningAction != true)
            Divider()
            Button("Next Suggestion") { window?.selectNext() }
                .keyboardShortcut("]", modifiers: [.command, .option])
                .disabled(window?.session.highlights.isEmpty ?? true)
            Button("Previous Suggestion") { window?.selectPrevious() }
                .keyboardShortcut("[", modifiers: [.command, .option])
                .disabled(window?.session.highlights.isEmpty ?? true)
            Button("Accept Suggestion") { window?.acceptSelected() }
                .keyboardShortcut(.return, modifiers: [.command, .option])
                .disabled(window?.selectedSuggestion?.canAccept != true || window?.isRunningAction == true)
            Button("Dismiss Suggestion") { window?.dismissSelected() }
                .keyboardShortcut(.delete, modifiers: [.command, .option])
                .disabled(window?.selectedSuggestion == nil)
            Divider()
            Button("Clear Suggestions") { window?.clearSuggestions() }
                .disabled(window?.session.suggestions.isEmpty ?? true)
        }
    }

    @ViewBuilder
    private func actionButton(_ action: AIActionConfig, index: Int) -> some View {
        let button = Button(action.name) { window?.run(action) }
            .disabled(window == nil || window?.isRunningAction == true)
        if index < 9 {
            button.keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command, .option])
        } else {
            button
        }
    }
}

/// Help ▸ Markdown Help, for the front document.
private struct MarkdownHelpButton: View {
    let appModel: AppModel
    let window: DocumentWindowModel?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Markdown Help") {
            appModel.helpRequest = HelpRequest(
                isPelican: window?.isPelican
                    ?? (appModel.configuration(for: appModel.defaultProfileName).pelican.detection == .always),
                fileURL: window?.fileURL,
                profileName: window?.profileName ?? appModel.defaultProfileName)
            openWindow(id: HelpView.windowID)
        }
        // ⌘? is taken by the Help menu's search field.
        .keyboardShortcut("m", modifiers: [.command, .shift])
    }
}

/// File ▸ New Pelican Post: a new document from the configured template.
private struct NewPelicanPostButton: View {
    let template: String
    @Environment(\.newDocument) private var newDocument

    var body: some View {
        Button("New Pelican Post") {
            newDocument(MarkdownDocument(text: PostTemplate.expand(template)))
        }
        .keyboardShortcut("n", modifiers: [.command, .option])
    }
}
