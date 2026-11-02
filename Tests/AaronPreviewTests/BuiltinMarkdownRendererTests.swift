import Foundation
import Testing
@testable import AaronPreview

struct BuiltinMarkdownRendererTests {
    let renderer = BuiltinMarkdownRenderer()

    func render(_ text: String) async throws -> String {
        try await renderer.render(PreviewRequest(text: text, fileURL: nil))
    }

    @Test func rendersMarkdownToHTML() async throws {
        let html = try await render("# Hello\n\nSome *em* text.")
        #expect(html.contains("<h1>Hello</h1>"))
        #expect(html.contains("<em>em</em>"))
    }

    @Test func producesFullPageWithStylesheet() async throws {
        let html = try await render("x")
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("<style>"))
        #expect(html.contains("prefers-color-scheme: dark"))
    }

    @Test func rendersGitHubTables() async throws {
        let html = try await render("| a | b |\n|---|---|\n| 1 | 2 |")
        #expect(html.contains("<table>"))
    }

    @Test func pelicanMetadataBecomesHeaderNotBody() async throws {
        let html = try await render("Title: My <Post>\nTags: a, b\n\nBody")
        #expect(html.contains(#"<h1 class="aaron-title">My &lt;Post&gt;</h1>"#))
        #expect(html.contains("<dt>Tags</dt><dd>a, b</dd>"))
        #expect(!html.contains("Title:"))
        #expect(html.contains("<p>Body</p>"))
    }

    @Test func yamlFrontMatterIsStripped() async throws {
        let html = try await render("---\ntitle: T\n---\nBody")
        #expect(!html.contains("---"))
        #expect(html.contains(#"<h1 class="aaron-title">T</h1>"#))
    }

    @Test func escapesInlineCodeCodeBlocksAndText() async throws {
        let html = try await render("Use `<div>` & `</div>`.\n\n```\n<https://example.com>\n```\n\n5 > 3")
        #expect(html.contains("<code>&lt;div&gt;</code> &amp; <code>&lt;/div&gt;</code>"))
        #expect(html.contains("<pre><code>&lt;https://example.com&gt;\n</code></pre>"))
        #expect(html.contains("<p>5 &gt; 3</p>"))
    }

    @Test func headingsKeepInlineFormatting() async throws {
        let html = try await render("## Only in `extra`")
        #expect(html.contains("<h2>Only in <code>extra</code></h2>"))
    }

    @Test func escapesAttributesAndKeepsImageAltText() async throws {
        let html = try await render(#"[a](https://x.com/?a=1&b="2") ![A cat](cat.jpg "Tom")"#)
        #expect(html.contains(#"<a href="https://x.com/?a=1&amp;b=&quot;2&quot;">a</a>"#))
        #expect(html.contains(#"<img src="cat.jpg" alt="A cat" title="Tom">"#))
    }

    @Test func rawHTMLIsPassedThrough() async throws {
        let html = try await render("<div class=\"x\">hi</div>")
        #expect(html.contains("<div class=\"x\">hi</div>"))
    }
}
