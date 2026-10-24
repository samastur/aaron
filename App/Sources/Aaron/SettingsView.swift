import AaronCore
import AaronPelican
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Preview", systemImage: "doc.richtext") { PreviewSettings() }
            Tab("AI", systemImage: "sparkles") { AISettings() }
            Tab("Pelican", systemImage: "tag") { PelicanSettingsView() }
        }
        .frame(width: 760, height: 560)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel
        Form {
            Section("Editor") {
                LabeledContent("Font size") {
                    HStack {
                        TextField("", value: $appModel.configuration.editor.fontSize, format: .number)
                            .frame(width: 60)
                        Stepper("", value: $appModel.configuration.editor.fontSize, in: EditorSettings.fontSizeRange, step: 1)
                            .labelsHidden()
                    }
                }
                Toggle("Use a monospaced font", isOn: $appModel.configuration.editor.monospaced)
            }
            Section("Configuration file") {
                Text(appModel.configurationURL.path)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                Text("Settings are saved automatically. You can also edit the file by hand and reload it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Show in Finder") { appModel.revealConfigurationFile() }
                    Button("Reload from Disk") { appModel.reloadConfiguration() }
                    Button("Restore Defaults…") { confirmReset = true }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Restore all settings to their defaults?", isPresented: $confirmReset) {
            Button("Restore Defaults", role: .destructive) { appModel.configuration = .default }
        } message: {
            Text("Preview renderers, AI providers and actions you added will be removed.")
        }
    }

    @State private var confirmReset = false
}

// MARK: - Preview

private struct PreviewSettings: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel
        let renderers = [(PreviewRendererConfig.builtinID, "Markdown (built-in)")]
            + appModel.configuration.previewRenderers.map { ($0.id, $0.name) }
        VStack(alignment: .leading, spacing: 12) {
            Form {
                Picker("Default for Markdown documents", selection: $appModel.configuration.defaultRenderer.markdown) {
                    ForEach(renderers, id: \.0) { Text($0.1).tag($0.0) }
                }
                Picker("Default for Pelican posts", selection: $appModel.configuration.defaultRenderer.pelican) {
                    ForEach(renderers, id: \.0) { Text($0.1).tag($0.0) }
                }
            }
            .formStyle(.grouped)
            .frame(height: 110)
            Text("External renderers")
                .font(.headline)
                .padding(.horizontal)
            ItemListEditor(items: $appModel.configuration.previewRenderers,
                           newItem: { PreviewRendererConfig(name: "New Renderer", command: "") },
                           title: \.name) { $renderer in
                RendererDetail(renderer: $renderer)
            }
        }
        .padding(.bottom)
    }
}

private struct RendererDetail: View {
    @Binding var renderer: PreviewRendererConfig

    var body: some View {
        Form {
            TextField("Name", text: $renderer.name)
            LabeledContent("Command") {
                CommandEditor(text: $renderer.command)
            }
            Text("The document is sent on standard input; the command prints HTML. Placeholders: {file}, {dir}, {filename}, {stem}, {relpath}, {tmpfile}.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Working directory", text: optional($renderer.workingDirectory), prompt: Text("document's folder"))
            TextField("{relpath} relative to", text: optional($renderer.baseDirectory), prompt: Text("e.g. ~/blog/content"))
            TextField("Timeout (seconds)", value: $renderer.timeoutSeconds, format: .number)
            Toggle("Allow JavaScript in the preview", isOn: $renderer.allowsJavaScript)
            Text("Only for renderers whose pages need scripts. Scripts in a document could read files the preview can reach.")
                .font(.caption).foregroundStyle(.secondary)
            Section("Asset folders") {
                Text("Serve URLs starting with a prefix (e.g. /articles/) from a local folder, so theme styles and images load.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach($renderer.assetMappings) { $mapping in
                    HStack {
                        TextField("URL prefix", text: $mapping.urlPrefix).frame(width: 120)
                        TextField("Folder", text: $mapping.directory)
                        Button {
                            renderer.assetMappings.removeAll { $0.id == mapping.id }
                        } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add Folder") {
                    renderer.assetMappings.append(AssetMapping(urlPrefix: "/", directory: ""))
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - AI

private struct AISettings: View {
    @Environment(AppModel.self) private var appModel
    @State private var section = 0

    var body: some View {
        @Bindable var appModel = appModel
        VStack(spacing: 8) {
            Picker("", selection: $section) {
                Text("Actions").tag(0)
                Text("Providers").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.top, 8)
            if section == 0 {
                ItemListEditor(items: $appModel.configuration.aiActions,
                               newItem: { AIActionConfig(name: "New Action", prompt: "",
                                                         providerID: appModel.configuration.aiProviders.first?.id ?? "") },
                               title: \.name) { $action in
                    ActionDetail(action: $action, providers: appModel.configuration.aiProviders)
                }
            } else {
                ItemListEditor(items: $appModel.configuration.aiProviders,
                               newItem: { AIProviderConfig(name: "New Provider", command: "") },
                               title: \.name) { $provider in
                    ProviderDetail(provider: $provider)
                }
            }
        }
        .padding(.bottom)
    }
}

private struct ActionDetail: View {
    @Binding var action: AIActionConfig
    let providers: [AIProviderConfig]

    var body: some View {
        Form {
            TextField("Name", text: $action.name)
                .accessibilityIdentifier("itemName")
            Picker("Provider", selection: $action.providerID) {
                ForEach(providers) { Text($0.name).tag($0.id) }
                if !providers.contains(where: { $0.id == action.providerID }) {
                    Text("Missing provider").tag(action.providerID)
                }
            }
            Section {
                TextEditor(text: $action.prompt)
                    .font(.body)
                    .frame(minHeight: 200)
                    .accessibilityIdentifier("actionPrompt")
            } header: {
                Text("Prompt")
            } footer: {
                Text("Describe what to look for. Aaron adds the document and the instructions for the answer format.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ProviderDetail: View {
    @Binding var provider: AIProviderConfig

    var body: some View {
        Form {
            TextField("Name", text: $provider.name)
            LabeledContent("Command") {
                CommandEditor(text: $provider.command)
            }
            Text("The prompt is sent on standard input; the command prints the AI's answer. Examples: claude -p --tools \"\"   ·   codex exec --skip-git-repo-check -")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Timeout (seconds)", value: $provider.timeoutSeconds, format: .number)
        }
        .formStyle(.grouped)
    }
}

// MARK: - Pelican

private struct PelicanSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var testResult: String?
    @State private var testing = false

    var body: some View {
        @Bindable var appModel = appModel
        Form {
            Picker("Pelican mode", selection: $appModel.configuration.pelican.detection) {
                Text("Automatic").tag(PelicanSettings.Detection.automatic)
                Text("Always on").tag(PelicanSettings.Detection.always)
                Text("Off").tag(PelicanSettings.Detection.never)
            }
            Text("Automatic: documents that start with Pelican metadata (Title: …) are Pelican posts.")
                .font(.caption).foregroundStyle(.secondary)
            Section("Tags") {
                LabeledContent("Tag command") {
                    CommandEditor(text: $appModel.configuration.pelican.tagsCommand)
                }
                Text("Prints the known tags, as JSON ({\"tags\": [{\"name\": …, \"count\": …}]}) or one per line. Placeholders such as {dir} refer to the open document.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Working directory", text: optional($appModel.configuration.pelican.tagsWorkingDirectory),
                          prompt: Text("document's folder"))
                TextField("Timeout (seconds)", value: $appModel.configuration.pelican.tagsTimeoutSeconds, format: .number)
                HStack {
                    Button("Test Command") { test() }
                        .disabled(testing || appModel.configuration.pelican.tagsCommand.isEmpty)
                    if testing { ProgressView().controlSize(.small) }
                    if let testResult {
                        Text(testResult).font(.callout).textSelection(.enabled).lineLimit(4)
                    }
                }
            }
            Section("New post template") {
                TextEditor(text: $appModel.configuration.pelican.newPostTemplate)
                    .font(.body.monospaced())
                    .frame(minHeight: 120)
                Text("Used by File ▸ New Pelican Post. {date} and {day} become the current date.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func test() {
        let pelican = appModel.configuration.pelican
        testing = true
        testResult = nil
        Task {
            do {
                let command = CommandTemplate.expand(pelican.tagsCommand,
                                                     context: CommandContext(fileURL: nil, baseDirectory: nil, temporaryFileURL: nil))
                let tags = try await appModel.tagProvider.tags(
                    command: command, workingDirectory: PathExpansion.url(pelican.tagsWorkingDirectory),
                    timeout: .seconds(pelican.tagsTimeoutSeconds), refresh: true)
                testResult = "\(tags.count) tags: " + tags.prefix(8).map(\.name).joined(separator: ", ")
            } catch {
                testResult = error.localizedDescription
            }
            testing = false
        }
    }
}

// MARK: - Shared

/// A small multi-line editor for shell commands.
private struct CommandEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.callout.monospaced())
            .frame(minHeight: 54, maxHeight: 90)
            .autocorrectionDisabled()
            .scrollContentBackground(.hidden)
            .padding(4)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
    }
}

/// Binds an optional string to a text field; empty means nil.
private func optional(_ binding: Binding<String?>) -> Binding<String> {
    Binding(get: { binding.wrappedValue ?? "" },
            set: { binding.wrappedValue = $0.isEmpty ? nil : $0 })
}

/// A list with add/remove/reorder controls and a detail editor.
private struct ItemListEditor<Item: Identifiable, Detail: View>: View where Item.ID == String {
    @Binding var items: [Item]
    let newItem: () -> Item
    let title: KeyPath<Item, String>
    @ViewBuilder let detail: (Binding<Item>) -> Detail
    @State private var selection: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(items) { item in
                        Text(item[keyPath: title]).tag(item.id)
                    }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                }
                Divider()
                HStack(spacing: 2) {
                    Button { add() } label: { Image(systemName: "plus") }
                        .accessibilityIdentifier("addItem")
                    Button { remove() } label: { Image(systemName: "minus") }
                        .disabled(selection == nil)
                        .accessibilityIdentifier("removeItem")
                    Spacer()
                    Button { move(-1) } label: { Image(systemName: "chevron.up") }
                        .disabled(selection == nil)
                    Button { move(1) } label: { Image(systemName: "chevron.down") }
                        .disabled(selection == nil)
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(width: 210)
            .background(.background)
            Divider()
            if let index = items.firstIndex(where: { $0.id == selection }) {
                detail($items[index])
                    .id(items[index].id)
            } else {
                Text("Select an item, or add one with +.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
        .padding(.horizontal)
        .onAppear { if selection == nil { selection = items.first?.id } }
    }

    private func add() {
        let item = newItem()
        items.append(item)
        selection = item.id
    }

    private func remove() {
        guard let index = items.firstIndex(where: { $0.id == selection }) else { return }
        items.remove(at: index)
        selection = items.indices.contains(index) ? items[index].id : items.last?.id
    }

    private func move(_ offset: Int) {
        guard let index = items.firstIndex(where: { $0.id == selection }) else { return }
        let target = index + offset
        guard items.indices.contains(target) else { return }
        items.swapAt(index, target)
    }
}
