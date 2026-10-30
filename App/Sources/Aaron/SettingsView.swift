import AaronCore
import AaronPelican
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        TabView {
            Tab("Profiles", systemImage: "person.2") { ProfilesSettings() }
            Tab("General", systemImage: "gearshape") { WithProfilePicker { GeneralSettings() } }
            Tab("Preview", systemImage: "doc.richtext") { WithProfilePicker { PreviewSettings() } }
            Tab("AI", systemImage: "sparkles") { WithProfilePicker { AISettings() } }
            Tab("Pelican", systemImage: "tag") { WithProfilePicker { PelicanSettingsView() } }
        }
        .frame(width: 760, height: 600)
        .onAppear {
            // Edit the profile of the window that was in front.
            appModel.settingsProfileName = appModel.frontProfileName ?? appModel.defaultProfileName
        }
    }
}

/// The settings tabs edit one profile, chosen at the top.
private struct WithProfilePicker<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel
        VStack(spacing: 0) {
            HStack {
                Picker("Profile", selection: $appModel.settingsProfileName) {
                    ForEach(appModel.profileNames, id: \.self) { name in
                        Text(name == appModel.defaultProfileName ? "\(name) (default)" : name).tag(name)
                    }
                }
                .fixedSize()
                .accessibilityIdentifier("settingsProfile")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            Divider()
            content()
        }
    }
}

// MARK: - Profiles

private struct ProfilesSettings: View {
    @Environment(AppModel.self) private var appModel
    @State private var name = ""
    @State private var error: String?
    @State private var confirmDelete = false
    @State private var importSource: URL?
    @State private var importName = ""

    var body: some View {
        @Bindable var appModel = appModel
        let selected = appModel.settingsProfileName
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                List(selection: Binding(get: { selected }, set: { if let new = $0 { appModel.settingsProfileName = new } })) {
                    ForEach(appModel.profileNames, id: \.self) { profile in
                        HStack {
                            Text(profile)
                            Spacer()
                            if profile == appModel.defaultProfileName {
                                Text("Default").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tag(profile)
                    }
                }
                .accessibilityIdentifier("profileList")
                Divider()
                HStack(spacing: 2) {
                    Button { perform { appModel.settingsProfileName = try appModel.addProfile(copying: selected) } } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add a copy of the selected profile")
                    .accessibilityIdentifier("addProfile")
                    Button { confirmDelete = true } label: { Image(systemName: "minus") }
                        .disabled(selected == appModel.defaultProfileName || appModel.profileNames.count < 2)
                        .help("Delete the selected profile (not the default)")
                        .accessibilityIdentifier("deleteProfile")
                    Spacer()
                    Button("Import…") { chooseImport() }
                        .accessibilityIdentifier("importProfile")
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(width: 220)
            .background(.background)
            Divider()
            Form {
                Section {
                    TextField("Name", text: $name)
                        .onSubmit { rename() }
                        .accessibilityIdentifier("profileName")
                    if let error {
                        Text(error).foregroundStyle(.red).font(.callout)
                            .accessibilityIdentifier("profileError")
                    }
                    LabeledContent("Default") {
                        if selected == appModel.defaultProfileName {
                            Text("New windows use this profile.")
                        } else {
                            Button("Set as Default") { perform { try appModel.setDefaultProfile(selected) } }
                                .accessibilityIdentifier("setDefaultProfile")
                        }
                    }
                }
                Section("File") {
                    Text(appModel.profileURL(selected).path)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                    HStack {
                        Button("Show in Finder") { appModel.revealProfilesFolder() }
                        Button("Reload All from Disk") { appModel.reloadProfiles() }
                    }
                }
                Section {
                    Text("Each window uses one profile: the default when it opens, or another chosen with "
                         + "View ▸ Profile or in its status bar. The other tabs edit the profile chosen at their top.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .onAppear { name = selected }
        .onChange(of: appModel.settingsProfileName) { _, new in name = new; error = nil }
        .confirmationDialog("Delete the profile “\(selected)”?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { perform { try appModel.deleteProfile(selected) } }
        } message: {
            Text("Its file is removed. Windows using it switch to the default profile.")
        }
        .alert("Import Profile", isPresented: Binding(get: { importSource != nil }, set: { if !$0 { importSource = nil } })) {
            TextField("Name", text: $importName)
            Button("Import") {
                if let source = importSource {
                    perform {
                        try appModel.importProfile(from: source, named: importName)
                        appModel.settingsProfileName = importName
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Name the new profile.")
        }
    }

    private func rename() {
        let old = appModel.settingsProfileName
        guard name != old else { return }
        perform { try appModel.renameProfile(old, to: name) }
        if error != nil { name = old }
    }

    private func chooseImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.message = "Choose a configuration file to add as a profile."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importName = url.deletingPathExtension().lastPathComponent
        importSource = url
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
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
                        TextField("", value: $appModel.settingsConfiguration.editor.fontSize, format: .number)
                            .frame(width: 60)
                            .accessibilityIdentifier("fontSize")
                        Stepper("", value: $appModel.settingsConfiguration.editor.fontSize, in: EditorSettings.fontSizeRange, step: 1)
                            .labelsHidden()
                    }
                }
                Toggle("Use a monospaced font", isOn: $appModel.settingsConfiguration.editor.monospaced)
            }
            Section {
                let panes = appModel.settingsConfiguration.panes
                Toggle("Editor", isOn: $appModel.settingsConfiguration.panes.editor)
                    .disabled(panes.editor && !panes.preview)
                    .accessibilityIdentifier("panesEditor")
                Toggle("Preview", isOn: $appModel.settingsConfiguration.panes.preview)
                    .disabled(panes.preview && !panes.editor)
                    .accessibilityIdentifier("panesPreview")
                Toggle("AI review", isOn: $appModel.settingsConfiguration.panes.review)
                    .accessibilityIdentifier("panesReview")
            } header: {
                Text("Panes")
            } footer: {
                Text("Shown when a window opens a file with this profile or switches to it. Turn off the editor to use Aaron as a reader.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Profile file") {
                Text(appModel.profileURL(appModel.settingsProfileName).path)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                Text("Settings are saved automatically. You can also edit the file by hand and reload it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Show in Finder") { appModel.revealProfilesFolder() }
                    Button("Reload All from Disk") { appModel.reloadProfiles() }
                    Button("Restore Defaults…") { confirmReset = true }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Restore profile “\(appModel.settingsProfileName)” to the defaults?",
                            isPresented: $confirmReset) {
            Button("Restore Defaults", role: .destructive) { appModel.settingsConfiguration = .default }
        } message: {
            Text("Preview renderers, AI providers and actions you added to this profile will be removed.")
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
            + appModel.settingsConfiguration.previewRenderers.map { ($0.id, $0.name) }
        VStack(alignment: .leading, spacing: 12) {
            Form {
                Picker("Default for Markdown documents", selection: $appModel.settingsConfiguration.defaultRenderer.markdown) {
                    ForEach(renderers, id: \.0) { Text($0.1).tag($0.0) }
                }
                Picker("Default for Pelican posts", selection: $appModel.settingsConfiguration.defaultRenderer.pelican) {
                    ForEach(renderers, id: \.0) { Text($0.1).tag($0.0) }
                }
            }
            .formStyle(.grouped)
            .frame(height: 110)
            Text("External renderers")
                .font(.headline)
                .padding(.horizontal)
            ItemListEditor(items: $appModel.settingsConfiguration.previewRenderers,
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
                ItemListEditor(items: $appModel.settingsConfiguration.aiActions,
                               newItem: { AIActionConfig(name: "New Action", prompt: "",
                                                         providerID: appModel.settingsConfiguration.aiProviders.first?.id ?? "") },
                               title: \.name) { $action in
                    ActionDetail(action: $action, providers: appModel.settingsConfiguration.aiProviders)
                }
            } else {
                ItemListEditor(items: $appModel.settingsConfiguration.aiProviders,
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
            Picker("Pelican mode", selection: $appModel.settingsConfiguration.pelican.detection) {
                Text("Automatic").tag(PelicanSettings.Detection.automatic)
                Text("Always on").tag(PelicanSettings.Detection.always)
                Text("Off").tag(PelicanSettings.Detection.never)
            }
            Text("Automatic: documents that start with Pelican metadata (Title: …) are Pelican posts.")
                .font(.caption).foregroundStyle(.secondary)
            Section("Tags") {
                LabeledContent("Tag command") {
                    CommandEditor(text: $appModel.settingsConfiguration.pelican.tagsCommand)
                }
                Text("Prints the known tags, as JSON ({\"tags\": [{\"name\": …, \"count\": …}]}) or one per line. Placeholders such as {dir} refer to the open document.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Working directory", text: optional($appModel.settingsConfiguration.pelican.tagsWorkingDirectory),
                          prompt: Text("document's folder"))
                TextField("Timeout (seconds)", value: $appModel.settingsConfiguration.pelican.tagsTimeoutSeconds, format: .number)
                HStack {
                    Button("Test Command") { test() }
                        .disabled(testing || appModel.settingsConfiguration.pelican.tagsCommand.isEmpty)
                    if testing { ProgressView().controlSize(.small) }
                    if let testResult {
                        Text(testResult).font(.callout).textSelection(.enabled).lineLimit(4)
                    }
                }
            }
            Section("Markdown Help") {
                LabeledContent("Plugins command") {
                    CommandEditor(text: $appModel.settingsConfiguration.pelican.pluginsCommand)
                }
                Text("Prints the names of the site's plugins, one per line, so Help ▸ Markdown Help can explain them. Runs in the post's folder; placeholders such as {dir} refer to the post.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Help folder", text: optional($appModel.settingsConfiguration.pelican.helpDirectory),
                          prompt: Text("optional, e.g. ~/blog/aaron-help"))
                Text("Your own help files, named after the plugin (e.g. my_plugin.md); they replace Aaron's.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("New post template") {
                TextEditor(text: $appModel.settingsConfiguration.pelican.newPostTemplate)
                    .font(.body.monospaced())
                    .frame(minHeight: 120)
                Text("Used by File ▸ New Pelican Post. {date} and {day} become the current date.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func test() {
        let pelican = appModel.settingsConfiguration.pelican
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
