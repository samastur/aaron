import Foundation
import Testing
@testable import AaronHelp

struct HelpLibraryTests {
    let library = HelpLibrary(extraDirectory: nil)

    @Test func markdownHelpIsAlwaysIncluded() {
        let help = library.markdown(pelican: nil)
        #expect(help.contains("# Markdown help"))
        #expect(help.contains("**bold**"))
        #expect(!help.contains("{filename}"))
    }

    @Test func pelicanSectionAppearsForPelicanPosts() {
        let help = library.markdown(pelican: PelicanHelpContext(plugins: [], pluginsCommandConfigured: true))
        #expect(help.contains("{filename}"))
        #expect(help.contains("## Plugins"))
    }

    @Test func bundledPluginHelpIsIncluded() {
        let plugins = PluginList.parse("pelican.plugins.simple_footnotes\npelican.plugins.sitemap")
        let help = library.markdown(pelican: PelicanHelpContext(plugins: plugins, pluginsCommandConfigured: true))
        #expect(help.contains("### simple_footnotes"))
        #expect(help.contains("[ref]"))
        #expect(help.contains("### sitemap"))
    }

    @Test func unknownPluginsAreListedWithAHint() {
        let help = library.markdown(pelican: PelicanHelpContext(plugins: PluginList.parse("my_own_plugin"),
                                                                pluginsCommandConfigured: true))
        #expect(help.contains("### my_own_plugin"))
        #expect(help.contains("my_own_plugin.md"))
    }

    @Test func missingPluginsCommandExplainsHowToSetItUp() {
        let help = library.markdown(pelican: PelicanHelpContext(plugins: [], pluginsCommandConfigured: false))
        #expect(help.contains("plugins command"))
    }

    @Test func pluginsCommandErrorIsShown() {
        let help = library.markdown(pelican: PelicanHelpContext(plugins: [], pluginsCommandConfigured: true,
                                                                error: "boom"))
        #expect(help.contains("boom"))
    }

    @Test func extraDirectoryOverridesAndExtendsBundledHelp() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("help-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "Use `{% mine %}`.".write(to: dir.appendingPathComponent("my_own_plugin.md"), atomically: true, encoding: .utf8)
        try "Custom footnotes help.".write(to: dir.appendingPathComponent("simple_footnotes.md"), atomically: true, encoding: .utf8)
        let help = HelpLibrary(extraDirectory: dir).markdown(pelican: PelicanHelpContext(
            plugins: PluginList.parse("my_own_plugin\nsimple_footnotes"), pluginsCommandConfigured: true))
        #expect(help.contains("{% mine %}"))
        #expect(help.contains("Custom footnotes help."))
    }

    @Test func everyBundledPluginHasAHelpFile() {
        #expect(library.bundledPluginKeys.count >= 5)
        for key in library.bundledPluginKeys {
            #expect(library.pluginHelp(for: key)?.isEmpty == false)
        }
    }
}
