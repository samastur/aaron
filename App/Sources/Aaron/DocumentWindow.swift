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
                let created = DocumentWindowModel(appModel: appModel)
                created.documentOpened(text: document.text, fileURL: fileURL)
                model = created
            }
        }
        .onChange(of: fileURL) { _, url in model?.fileURLChanged(url) }
        .onChange(of: document.text) { _, text in model?.textChanged(text) }
        .onChange(of: appModel.configuration) { _, _ in model?.configurationChanged() }
    }
}

private struct DocumentContent: View {
    @Binding var document: MarkdownDocument
    @Bindable var model: DocumentWindowModel
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                EditorView(text: $document.text, model: model, settings: appModel.configuration.editor)
                    .frame(minWidth: 320, idealWidth: 640)
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
                Toggle(isOn: $model.showPreview) {
                    Label("Preview", systemImage: "doc.richtext")
                }
                .help("Show or hide the preview (⌥⌘P)")
                .accessibilityIdentifier("togglePreview")

                AIActionsMenu(model: model)

                Toggle(isOn: $model.showReview) {
                    Label("Review", systemImage: "text.badge.checkmark")
                }
                .help("Show or hide AI review mode (⌥⌘R)")
                .accessibilityIdentifier("toggleReview")
            }
        }
        .focusedSceneValue(\.windowModel, model)
        .alert("Settings problem", isPresented: Binding(
            get: { appModel.configurationError != nil },
            set: { if !$0 { appModel.configurationError = nil } })) {
            Button("Show File") { appModel.revealConfigurationFile() }
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
            ForEach(appModel.configuration.aiActions) { action in
                Button(action.name) { model.run(action) }
            }
            if appModel.configuration.aiActions.isEmpty {
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
