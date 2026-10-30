import Foundation
import Testing
@testable import AaronCore

struct ConfigurationTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("aaron-tests-\(UUID().uuidString)")
            .appendingPathComponent("config.json")
    }

    @Test func defaultsProvideClaudeCodexAndThreeActions() {
        let config = Configuration.default
        #expect(config.aiProviders.map(\.name) == ["Claude", "Claude (web)", "Codex"])
        #expect(config.aiProviders[0].command.hasPrefix("claude -p"))
        #expect(config.aiActions.map(\.name) == ["Grammar and spelling", "Fact check", "Style"])
        #expect(config.aiActions.map(\.providerID) == ["claude", "claude-web", "claude"])
        #expect(config.previewRenderers.isEmpty)
        #expect(config.defaultRenderer.markdown == PreviewRendererConfig.builtinID)
        #expect(config.pelican.detection == .automatic)
    }

    @Test func roundTripsThroughStore() throws {
        let url = tempURL()
        var config = Configuration.default
        config.previewRenderers.append(PreviewRendererConfig(
            name: "Pelican", command: "preview {file}", workingDirectory: "~/blog",
            assetMappings: [AssetMapping(urlPrefix: "/articles/", directory: "~/blog/output")]))
        config.editor.fontSize = 18
        try ConfigurationStore.save(config, to: url)
        #expect(try ConfigurationStore.load(from: url) == config)
    }

    @Test func missingFileGivesDefaults() throws {
        #expect(try ConfigurationStore.load(from: tempURL()) == .default)
    }

    @Test func invalidJSONThrows() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: url)
        #expect(throws: (any Error).self) { try ConfigurationStore.load(from: url) }
    }

    @Test func partialFileFillsInDefaults() throws {
        let json = #"""
        {"editor": {"monospaced": true},
         "aiActions": [{"name": "Tone", "prompt": "Check tone.", "providerID": "claude"}],
         "pelican": {"tagsCommand": "scripts/list-tags --json"}}
        """#
        let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
        #expect(config.editor.monospaced)
        #expect(config.editor.fontSize == 16)
        #expect(config.aiActions.count == 1)
        #expect(!config.aiActions[0].id.isEmpty)
        #expect(config.aiProviders == Configuration.default.aiProviders)
        #expect(config.pelican.tagsCommand == "scripts/list-tags --json")
        #expect(config.pelican.tagsTimeoutSeconds == 15)
        #expect(config.pelican.detection == .automatic)
    }

    @Test func panesDefaultToEditorAndPreview() throws {
        #expect(Configuration.default.panes == PaneSettings(editor: true, preview: true, review: false))
        let config = try JSONDecoder().decode(Configuration.self, from: Data(#"{"panes": {"editor": false}}"#.utf8))
        #expect(config.panes == PaneSettings(editor: false, preview: true, review: false))
    }

    @Test func effectivePanesNeverHideBothEditorAndPreview() {
        #expect(PaneSettings(editor: false, preview: false, review: true).effective
            == PaneSettings(editor: true, preview: false, review: true))
        #expect(PaneSettings(editor: false, preview: true).effective == PaneSettings(editor: false, preview: true))
    }

    @Test func expandsTildeInPaths() {
        #expect(PathExpansion.expand("~/blog") == NSHomeDirectory() + "/blog")
        #expect(PathExpansion.expand("/abs") == "/abs")
        #expect(PathExpansion.url("") == nil)
        #expect(PathExpansion.url("  ") == nil)
    }

    @Test func lookupHelpers() {
        let config = Configuration.default
        let action = config.aiActions[0]
        #expect(config.provider(for: action) == config.aiProviders[0])
        #expect(config.renderer(withID: "missing") == nil)
    }
}

struct DefaultRendererSelectionTests {
    @Test func picksRendererByDocumentKind() {
        var config = Configuration.default
        let pelican = PreviewRendererConfig(id: "pel", name: "Pelican", command: "x")
        config.previewRenderers = [pelican]
        config.defaultRenderer.pelican = "pel"
        #expect(config.defaultRendererID(isPelican: true) == "pel")
        #expect(config.defaultRendererID(isPelican: false) == PreviewRendererConfig.builtinID)
    }

    @Test func unknownRendererFallsBackToBuiltin() {
        var config = Configuration.default
        config.defaultRenderer.pelican = "deleted"
        #expect(config.defaultRendererID(isPelican: true) == PreviewRendererConfig.builtinID)
    }

    @Test func defaultEditorFontSizeIs16() {
        #expect(EditorSettings().fontSize == 16)
    }

    @Test func helpSettingsDefaultToEmptyAndDecode() throws {
        #expect(Configuration.default.pelican.pluginsCommand == "")
        #expect(Configuration.default.pelican.helpDirectory == nil)
        let json = #"{"pelican": {"pluginsCommand": "list", "helpDirectory": "~/help"}}"#
        let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
        #expect(config.pelican.pluginsCommand == "list")
        #expect(config.pelican.helpDirectory == "~/help")
    }

    @Test func newPostTemplateHasDefault() {
        #expect(Configuration.default.pelican.newPostTemplate.contains("Title: "))
        #expect(Configuration.default.pelican.newPostTemplate.contains("{date}"))
    }
}

struct ValidationTests {
    @Test func fontSizeIsClampedToSupportedRange() {
        var editor = EditorSettings()
        editor.fontSize = 0
        #expect(editor.effectiveFontSize == 9)
        editor.fontSize = 500
        #expect(editor.effectiveFontSize == 36)
        editor.fontSize = 17
        #expect(editor.effectiveFontSize == 17)
    }

    @Test func renderersDisallowJavaScriptByDefault() throws {
        let json = #"{"previewRenderers": [{"name": "R", "command": "x"}]}"#
        let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
        #expect(config.previewRenderers[0].allowsJavaScript == false)
        #expect(PreviewRendererConfig(name: "R", command: "x").allowsJavaScript == false)
    }
}
