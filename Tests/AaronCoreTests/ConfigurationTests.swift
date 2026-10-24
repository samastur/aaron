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
        #expect(config.editor.fontSize == 15)
        #expect(config.aiActions.count == 1)
        #expect(!config.aiActions[0].id.isEmpty)
        #expect(config.aiProviders == Configuration.default.aiProviders)
        #expect(config.pelican.tagsCommand == "scripts/list-tags --json")
        #expect(config.pelican.tagsTimeoutSeconds == 15)
        #expect(config.pelican.detection == .automatic)
    }

    @Test func expandsTildeInPaths() {
        #expect(PathExpansion.expand("~/blog") == NSHomeDirectory() + "/blog")
        #expect(PathExpansion.expand("/abs") == "/abs")
        #expect(PathExpansion.url("") == nil)
        #expect(PathExpansion.url("  ") == nil)
    }

    @Test func environmentOverridesConfigLocation() {
        let url = ConfigurationStore.defaultURL(environment: ["AARON_CONFIG_PATH": "/tmp/x.json"])
        #expect(url.path == "/tmp/x.json")
        let normal = ConfigurationStore.defaultURL(environment: [:])
        #expect(normal.path.hasSuffix("Library/Application Support/Aaron/config.json"))
    }

    @Test func lookupHelpers() {
        let config = Configuration.default
        let action = config.aiActions[0]
        #expect(config.provider(for: action) == config.aiProviders[0])
        #expect(config.renderer(withID: "missing") == nil)
    }
}
