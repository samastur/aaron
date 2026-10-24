import Foundation

public struct StyleRun: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case heading, emphasis, strong, code, codeBlock, linkText, linkURL, quote, listMarker
        case metadataKey, metadataValue
    }

    public var kind: Kind
    public var range: NSRange
}

/// Lightweight, regex-based Markdown highlighting for the editor. It aims
/// to be fast and good enough for prose, not a complete Markdown parser.
public enum MarkdownHighlighter {
    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }

    private static let fence = regex(#"^[ ]{0,3}(```|~~~)"#)
    private static let heading = regex(#"^#{1,6}[ \t]+.*$"#)
    private static let quote = regex(#"^[ ]{0,3}>.*$"#)
    private static let listMarker = regex(#"^[ \t]*([-*+]|\d+\.)[ \t]+"#)
    private static let inlineCode = regex(#"`[^`\n]+`"#)
    private static let strong = regex(#"(?<![*\w])\*\*(?!\s)[^\n]*?\S\*\*(?![*\w])|(?<![_\w])__(?!\s)[^\n]*?\S__(?![_\w])"#)
    private static let emphasis = regex(#"(?<![*\w])\*(?![\s*])[^*\n]*?[^\s*]?\*(?![*\w])|(?<![_\w])_(?![\s_])[^_\n]*?[^\s_]?_(?![_\w])"#)
    private static let link = regex(#"\[([^\]\n]+)\]\(([^)\s]+)(?:[ \t]+"[^"\n]*")?\)"#)
    private static let autolink = regex(#"<(https?://[^>\s]+)>"#)

    public static func runs(in text: String) -> [StyleRun] {
        let ns = text as NSString
        var runs: [StyleRun] = []
        var bodyStart = 0

        if let frontMatter = FrontMatter.parse(text) {
            bodyStart = frontMatter.bodyStart
            for field in frontMatter.fields {
                runs.append(StyleRun(kind: .metadataKey, range: field.keyRange))
                if field.valueRange.length > 0 {
                    runs.append(StyleRun(kind: .metadataValue, range: field.valueRange))
                }
            }
        }
        let body = NSRange(location: bodyStart, length: ns.length - bodyStart)

        let codeBlocks = fencedBlocks(in: ns, body: body)
        runs += codeBlocks.map { StyleRun(kind: .codeBlock, range: $0) }
        var excluded = codeBlocks

        func add(_ kind: StyleRun.Kind, _ expression: NSRegularExpression, group: Int = 0) {
            expression.enumerateMatches(in: text, range: body) { match, _, _ in
                guard let match else { return }
                let whole = match.range
                guard !excluded.contains(where: { NSIntersectionRange($0, whole).length > 0 }) else { return }
                let range = match.range(at: group)
                if range.location != NSNotFound { runs.append(StyleRun(kind: kind, range: range)) }
            }
        }

        add(.code, inlineCode)
        excluded += runs.filter { $0.kind == .code }.map(\.range)
        add(.heading, heading)
        add(.quote, quote)
        add(.listMarker, listMarker, group: 1)
        add(.strong, strong)
        add(.emphasis, emphasis)
        add(.linkText, link, group: 1)
        add(.linkURL, link, group: 2)
        add(.linkURL, autolink, group: 1)

        return runs.sorted { $0.range.location < $1.range.location }
    }

    /// Ranges of fenced code blocks, fences included. An unclosed fence runs
    /// to the end of the document.
    private static func fencedBlocks(in text: NSString, body: NSRange) -> [NSRange] {
        var blocks: [NSRange] = []
        var openStart: Int?
        var openMarker = ""
        for line in Line.split(text) where line.range.location >= body.location {
            guard let match = fence.firstMatch(in: line.content, range: NSRange(location: 0, length: (line.content as NSString).length)) else {
                continue
            }
            let marker = (line.content as NSString).substring(with: match.range(at: 1))
            if let start = openStart {
                guard marker == openMarker else { continue }
                blocks.append(NSRange(location: start, length: NSMaxRange(line.range) - start))
                openStart = nil
            } else {
                openStart = line.range.location
                openMarker = marker
            }
        }
        if let start = openStart {
            blocks.append(NSRange(location: start, length: text.length - start))
        }
        return blocks
    }
}
