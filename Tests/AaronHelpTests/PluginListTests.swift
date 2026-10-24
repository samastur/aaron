import Testing
@testable import AaronHelp

struct PluginListTests {
    @Test func parsesOneNamePerLine() {
        #expect(PluginList.parse("pelican.plugins.simple_footnotes\n\npelican.plugins.sitemap\n").map(\.name)
                == ["pelican.plugins.simple_footnotes", "pelican.plugins.sitemap"])
    }

    @Test func parsesJSONListAndObject() {
        #expect(PluginList.parse(#"["a", "b"]"#).map(\.name) == ["a", "b"])
        #expect(PluginList.parse(#"{"plugins": ["c"]}"#).map(\.name) == ["c"])
    }

    @Test func keysIgnorePackagePrefixesCaseAndDashes() {
        let keys = PluginList.parse("pelican.plugins.simple_footnotes\npelican-sitemap\nRender-Math\nplugins.liquid_tags.liquid_tags")
            .map(\.key)
        #expect(keys == ["simple_footnotes", "sitemap", "render_math", "liquid_tags"])
    }

    @Test func duplicatesAreRemoved() {
        #expect(PluginList.parse("sitemap\npelican.plugins.sitemap").count == 1)
    }
}
