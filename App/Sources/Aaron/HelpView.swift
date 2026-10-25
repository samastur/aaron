import AaronCore
import AaronHelp
import AaronPreview
import SwiftUI

/// Which document Markdown Help was opened for.
struct HelpRequest: Equatable {
    var isPelican: Bool
    var fileURL: URL?
    /// The profile whose plugins command and help folder are used.
    var profileName: String
    /// Changes on every request, so reopening the window refreshes it.
    var id = UUID()
}

/// Help ▸ Markdown Help: the Markdown reference, plus Pelican syntax and the
/// site's plugins for Pelican posts.
struct HelpView: View {
    static let windowID = "markdown-help"

    @Environment(AppModel.self) private var appModel
    @State private var html = ""
    @State private var loading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(appModel.helpRequest.isPelican
                     ? "Markdown and Pelican" + (appModel.helpRequest.fileURL.map { " — \($0.lastPathComponent)" } ?? "")
                     : "Markdown")
                    .font(.headline)
                Spacer()
                if loading { ProgressView().controlSize(.small) }
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Load the help again, e.g. after changing plugins")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            PreviewWebView(html: html, resolver: PreviewAssetResolver(mappings: [], documentDirectory: nil),
                           allowsJavaScript: false)
                .accessibilityIdentifier("markdownHelp")
        }
        .frame(minWidth: 500, minHeight: 400)
        .task(id: appModel.helpRequest) { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        let request = appModel.helpRequest
        let pelicanSettings = appModel.configuration(for: request.profileName).pelican
        var pelican: PelicanHelpContext?
        if request.isPelican {
            pelican = await pluginContext(pelicanSettings, fileURL: request.fileURL)
        }
        let library = HelpLibrary(extraDirectory: PathExpansion.url(pelicanSettings.helpDirectory))
        let markdown = library.markdown(pelican: pelican)
        html = (try? await BuiltinMarkdownRenderer().render(PreviewRequest(text: markdown, fileURL: nil))) ?? ""
    }

    private func pluginContext(_ settings: PelicanSettings, fileURL: URL?) async -> PelicanHelpContext {
        let command = settings.pluginsCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            return PelicanHelpContext(plugins: [], pluginsCommandConfigured: false)
        }
        let expanded = CommandTemplate.expand(command, context: CommandContext(
            fileURL: fileURL, baseDirectory: nil, temporaryFileURL: nil))
        var directory = fileURL?.deletingLastPathComponent()
        if let dir = directory, !FileManager.default.fileExists(atPath: dir.path) { directory = nil }
        do {
            let result = try await ProcessRunner().run(expanded, workingDirectory: directory,
                                                       timeout: .seconds(settings.tagsTimeoutSeconds))
            return PelicanHelpContext(plugins: PluginList.parse(result.stdout), pluginsCommandConfigured: true)
        } catch {
            return PelicanHelpContext(plugins: [], pluginsCommandConfigured: true,
                                      error: error.localizedDescription)
        }
    }
}
