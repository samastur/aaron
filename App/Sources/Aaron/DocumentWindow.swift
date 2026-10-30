import AaronCore
import SwiftUI

struct DocumentWindow: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?

    @Environment(AppModel.self) private var appModel
    @State private var model: DocumentWindowModel?

    var body: some View {
        Group {
            if let model {
                DocumentContent(document: $document, model: model)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if model == nil {
                let created = DocumentWindowModel(appModel: appModel, profileName: appModel.pendingProfile(for: fileURL))
                appModel.register(created)
                created.editor.load(text: $document.text, model: created)
                created.documentOpened(text: document.text, fileURL: fileURL)
                model = created
                #if DEBUG
                DebugHarness.attach(created)
                #endif
            }
        }
        .onChange(of: fileURL) { _, url in model?.fileURLChanged(url) }
        .onChange(of: document.text) { _, text in
            model?.textChanged(text)
            model?.editor.documentChanged(text)
        }
    }
}

private struct DocumentContent: View {
    @Binding var document: MarkdownDocument
    @Bindable var model: DocumentWindowModel
    @Environment(AppModel.self) private var appModel
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                if model.showEditor {
                    EditorView(text: $document.text, model: model, settings: model.configuration.editor)
                        .frame(minWidth: 320, idealWidth: 640)
                }
                if model.showPreview {
                    PreviewPane(model: model)
                        .frame(minWidth: 280, idealWidth: 520)
                }
            }
            Divider()
            StatusBar(model: model)
        }
        .inspector(isPresented: $model.showReview) {
            SuggestionsPanel(model: model)
                .inspectorColumnWidth(min: 280, ideal: 340, max: 520)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $model.showEditor) {
                    Label("Editor", systemImage: "square.and.pencil")
                }
                .disabled(model.showEditor && !model.canHideEditor)
                .help("Show or hide the editor (⌥⌘E)")
                .accessibilityIdentifier("toggleEditor")

                Toggle(isOn: $model.showPreview) {
                    Label("Preview", systemImage: "doc.richtext")
                }
                .disabled(model.showPreview && !model.canHidePreview)
                .help("Show or hide the preview (⌥⌘P)")
                .accessibilityIdentifier("togglePreview")

                AIActionsMenu(model: model)

                ProfileMenu(model: model)

                Toggle(isOn: $model.showReview) {
                    Label("Review", systemImage: "text.badge.checkmark")
                }
                .help("Show or hide AI review mode (⌥⌘R)")
                .accessibilityIdentifier("toggleReview")
            }
        }
        .focusedSceneValue(\.windowModel, model)
        // Settings opens on the profile of the window last in front.
        .onChange(of: appearsActive, initial: true) { _, active in
            if active { appModel.frontProfileName = model.profileName }
        }
        .onChange(of: model.profileName) { _, name in
            if appearsActive { appModel.frontProfileName = name }
        }
        .alert("Settings problem", isPresented: Binding(
            get: { appModel.configurationError != nil },
            set: { if !$0 { appModel.configurationError = nil } })) {
            Button("Show File") { appModel.revealProfilesFolder() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(appModel.configurationError ?? "")
        }
    }
}

/// Toolbar menu listing the configured AI actions.
struct AIActionsMenu: View {
    let model: DocumentWindowModel
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Menu {
            ForEach(model.configuration.aiActions) { action in
                Button(action.name) { model.run(action) }
            }
            if model.configuration.aiActions.isEmpty {
                Text("No AI actions configured")
            }
            Divider()
            SettingsLink { Text("Edit Actions…") }
        } label: {
            Label("AI Actions", systemImage: "sparkles")
        }
        .disabled(model.isRunningAction)
        .help("Run an AI action on the document or the selection")
        .accessibilityIdentifier("aiActionsMenu")
    }
}

/// Toolbar menu for choosing the window's profile.
struct ProfileMenu: View {
    let model: DocumentWindowModel

    var body: some View {
        ProfilePicker(model: model) {
            Label("Profile: \(model.profileName)", systemImage: "slider.horizontal.3")
        }
        .help("Profile used by this window: \(model.profileName)")
        .accessibilityIdentifier("profileMenu")
    }
}

/// A menu listing the profiles, with the window's one checked.
struct ProfilePicker<MenuLabel: View>: View {
    @Bindable var model: DocumentWindowModel
    @ViewBuilder var label: () -> MenuLabel
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Menu {
            Picker("Profile", selection: $model.profileName) {
                ForEach(appModel.profileNames, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            Divider()
            SettingsLink { Text("Edit Profiles…") }
        } label: {
            label()
        }
    }
}

struct StatusBar: View {
    let model: DocumentWindowModel

    var body: some View {
        HStack(spacing: 14) {
            Text("\(model.statistics.words) words")
                .accessibilityIdentifier("wordCount")
            Text("\(model.statistics.characters) characters")
            Spacer()
            if model.isPelican {
                if let error = model.tagError {
                    Label("Tags unavailable", systemImage: "exclamationmark.triangle")
                        .help(error)
                } else if !model.tags.isEmpty {
                    Text("\(model.tags.count) tags")
                }
            }
            Text(model.isPelican ? "Pelican" : "Markdown")
                .accessibilityIdentifier("documentMode")
            ProfilePicker(model: model) {
                Text(model.profileName)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .help("Profile used by this window")
            .accessibilityIdentifier("statusProfile")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

extension FocusedValues {
    @Entry var windowModel: DocumentWindowModel?
}
