import AaronCore
import Foundation
import Markdown

/// Renders CommonMark + GitHub tables/strikethrough with swift-markdown.
/// A leading metadata block is shown as a header instead of as text.
public struct BuiltinMarkdownRenderer: PreviewRenderer {
    public init() {}

    public func render(_ request: PreviewRequest) async throws -> String {
        var body = request.text
        var header = ""
        if let frontMatter = FrontMatter.parse(request.text) {
            body = (request.text as NSString).substring(from: frontMatter.bodyStart)
            header = Self.header(for: frontMatter)
        }
        let content = HTMLFormatter.format(Document(parsing: body))
        return Self.page(header + content)
    }

    static func header(for frontMatter: FrontMatter) -> String {
        var html = ""
        if let title = frontMatter.value(for: "title") {
            html += #"<h1 class="aaron-title">\#(HTML.escape(title))</h1>"#
        }
        let others = frontMatter.fields.filter { $0.key.caseInsensitiveCompare("title") != .orderedSame }
        if !others.isEmpty {
            html += #"<dl class="aaron-meta">"#
            for field in others {
                html += "<dt>\(HTML.escape(field.key))</dt><dd>\(HTML.escape(field.value))</dd>"
            }
            html += "</dl>"
        }
        return html + "\n"
    }

    static func page(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(stylesheet)</style>
        </head><body>
        \(body)
        </body></html>
        """
    }

    static let stylesheet = """
    :root { color-scheme: light dark; --fg: #1d1d1f; --muted: #6e6e73; --bg: #ffffff;
            --code-bg: #f2f2f5; --rule: #d2d2d7; --link: #0066cc; }
    @media (prefers-color-scheme: dark) {
      :root { --fg: #e8e8ed; --muted: #a1a1a6; --bg: #1e1e1e; --code-bg: #2c2c2e;
              --rule: #3a3a3c; --link: #4da3ff; }
    }
    body { font: 16px/1.6 -apple-system, "Helvetica Neue", sans-serif; color: var(--fg);
           background: var(--bg); max-width: 44em; margin: 0 auto; padding: 1.5em 1.5em 4em; }
    h1, h2, h3, h4 { line-height: 1.25; margin: 1.6em 0 0.6em; }
    h1.aaron-title { margin-top: 0.4em; }
    a { color: var(--link); }
    img { max-width: 100%; height: auto; }
    code, pre { font: 0.9em ui-monospace, "SF Mono", Menlo, monospace; background: var(--code-bg); border-radius: 4px; }
    code { padding: 0.1em 0.3em; }
    pre { padding: 0.8em 1em; overflow-x: auto; }
    pre code { padding: 0; background: none; }
    blockquote { margin: 1em 0; padding: 0 1em; color: var(--muted); border-left: 3px solid var(--rule); }
    table { border-collapse: collapse; } th, td { border: 1px solid var(--rule); padding: 0.3em 0.6em; }
    hr { border: none; border-top: 1px solid var(--rule); }
    dl.aaron-meta { display: grid; grid-template-columns: max-content 1fr; gap: 0.1em 1em;
                    font-size: 0.85em; color: var(--muted); margin: 0 0 2em;
                    padding-bottom: 1em; border-bottom: 1px solid var(--rule); }
    dl.aaron-meta dt { font-weight: 600; } dl.aaron-meta dd { margin: 0; }
    """
}
