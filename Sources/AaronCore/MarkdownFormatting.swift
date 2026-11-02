import Foundation

/// A change to the editor's text: replace `range` with `replacement`, then
/// select `selection` (in the changed text). Ranges are UTF-16, as in
/// NSTextView.
public struct FormattingEdit: Equatable, Sendable {
    public var range: NSRange
    public var replacement: String
    public var selection: NSRange

    public init(range: NSRange, replacement: String, selection: NSRange) {
        self.range = range
        self.replacement = replacement
        self.selection = selection
    }

    /// The text after the edit.
    public func applied(to text: String) -> String {
        (text as NSString).replacingCharacters(in: range, with: replacement)
    }
}

/// The editor's Format commands: bold, italic, link, quote and HTML.
public enum MarkdownFormatting {
    // MARK: Bold and italic

    public static func toggleBold(in text: String, selection: NSRange) -> FormattingEdit {
        toggleEmphasis(in: text, selection: selection, width: 2)
    }

    public static func toggleItalic(in text: String, selection: NSRange) -> FormattingEdit {
        toggleEmphasis(in: text, selection: selection, width: 1)
    }

    /// Bold is a run of two (or three: bold italic) `*` or `_` on both
    /// sides, italic a run of one (or three). Removes the markers if the
    /// selection is already formatted (with the markers inside or just
    /// outside the selection), otherwise adds them. Without a selection, the
    /// word at the caret is used, or an empty pair is inserted.
    private static func toggleEmphasis(in text: String, selection: NSRange, width: Int) -> FormattingEdit {
        let ns = text as NSString
        let marker = String(repeating: "*", count: width)
        let isFormatted = { (run: Int) in width == 2 ? (run == 2 || run == 3) : (run == 1 || run == 3) }

        var target = trimmingWhitespace(selection, in: ns)
        if target.length == 0 {
            // Caret between an empty pair: remove it.
            let char = character(before: target.location, in: ns)
            if let char, isMarker(char) {
                let left = run(of: char, endingAt: target.location, in: ns)
                let right = run(of: char, startingAt: target.location, in: ns)
                if left == right, isFormatted(left) {
                    let range = NSRange(location: target.location - width, length: 2 * width)
                    return FormattingEdit(range: range, replacement: "",
                                          selection: NSRange(location: range.location, length: 0))
                }
            }
            target = word(at: target.location, in: ns)
        }
        if target.length == 0 {
            return FormattingEdit(range: target, replacement: marker + marker,
                                  selection: NSRange(location: target.location + width, length: 0))
        }

        // Markers just outside the selection.
        if let char = character(before: target.location, in: ns), isMarker(char),
           character(at: NSMaxRange(target), in: ns) == char {
            let left = run(of: char, endingAt: target.location, in: ns)
            let right = run(of: char, startingAt: NSMaxRange(target), in: ns)
            if isFormatted(left), isFormatted(right) {
                let range = NSRange(location: target.location - width, length: target.length + 2 * width)
                return FormattingEdit(range: range, replacement: ns.substring(with: target),
                                      selection: NSRange(location: range.location, length: target.length))
            }
        }
        // Markers at the ends of the selection.
        let selected = ns.substring(with: target) as NSString
        if let char = character(at: 0, in: selected), isMarker(char) {
            let left = run(of: char, startingAt: 0, in: selected)
            let right = run(of: char, endingAt: selected.length, in: selected)
            if left + right < selected.length, isFormatted(left), isFormatted(right) {
                let inner = selected.substring(with: NSRange(location: width, length: selected.length - 2 * width))
                return FormattingEdit(range: target, replacement: inner,
                                      selection: NSRange(location: target.location, length: (inner as NSString).length))
            }
        }
        return FormattingEdit(range: target, replacement: marker + (selected as String) + marker,
                              selection: NSRange(location: target.location + width, length: target.length))
    }

    // MARK: Links

    /// Makes `[text](url)` of the selection. The URL is the selection if it
    /// is one, otherwise `clipboardURL` if given, otherwise empty. The caret
    /// goes where typing is still needed: the text, the URL, or (when both
    /// are there) after the link.
    public static func insertLink(in text: String, selection: NSRange, clipboardURL: String?) -> FormattingEdit {
        let ns = text as NSString
        let target = trimmingWhitespace(selection, in: ns)
        let selected = ns.substring(with: target)
        if isURL(selected) {
            return FormattingEdit(range: target, replacement: "[](\(selected))",
                                  selection: NSRange(location: target.location + 1, length: 0))
        }
        let url = clipboardURL.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { isURL($0) ? $0 : nil }
        let replacement = "[\(selected)](\(url ?? ""))"
        let length = (replacement as NSString).length
        let caret: Int
        if selected.isEmpty {
            caret = target.location + 1
        } else if url == nil {
            caret = target.location + length - 1
        } else {
            caret = target.location + length
        }
        return FormattingEdit(range: target, replacement: replacement, selection: NSRange(location: caret, length: 0))
    }

    public static func isURL(_ text: String) -> Bool {
        text.range(of: #"^(https?://|mailto:)\S+$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: Quotes

    /// Quotes the selected lines with `> `, or removes one level of quoting
    /// if all of them (ignoring empty lines) are already quoted.
    public static func toggleQuote(in text: String, selection: NSRange) -> FormattingEdit {
        let ns = text as NSString
        var span = selection
        // A selection of whole lines ends after the last newline; don't
        // take in the following line.
        if span.length > 0, let last = character(at: NSMaxRange(span) - 1, in: ns), last == "\n" {
            span.length -= 1
        }
        let range = ns.lineRange(for: span)
        let block = ns.substring(with: range)
        var lines = block.components(separatedBy: "\n")
        // The newline ending the block is not a line of its own.
        let endsWithNewline = block.hasSuffix("\n")
        if endsWithNewline { lines.removeLast() }

        let isBlank = { (line: String) in line.trimmingCharacters(in: .whitespaces).isEmpty }
        let quotePrefix = #"^ {0,3}>"#
        let allQuoted = lines.contains { !isBlank($0) }
            && lines.allSatisfy { isBlank($0) || $0.range(of: quotePrefix, options: .regularExpression) != nil }
        let changed: [String]
        if allQuoted {
            changed = lines.map { line in
                guard let marker = line.range(of: #"^ {0,3}> ?"#, options: .regularExpression) else { return line }
                return String(line[marker.upperBound...])
            }
        } else if lines.count == 1, isBlank(lines[0]) {
            changed = ["> "]
        } else {
            changed = lines.map { isBlank($0) ? ">" : "> " + $0 }
        }
        let replacement = changed.joined(separator: "\n") + (endsWithNewline ? "\n" : "")
        let length = (replacement as NSString).length
        if lines.count == 1, selection.length == 0 {
            // Keep the caret where it was in the line.
            let offset = selection.location - range.location
            let delta = (changed[0] as NSString).length - (lines[0] as NSString).length
            let caret = range.location + max(0, min(offset + delta, (changed[0] as NSString).length))
            return FormattingEdit(range: range, replacement: replacement, selection: NSRange(location: caret, length: 0))
        }
        return FormattingEdit(range: range, replacement: replacement,
                              selection: NSRange(location: range.location, length: length - (endsWithNewline ? 1 : 0)))
    }

    // MARK: HTML

    private static let blockTags: Set<String> = [
        "address", "article", "aside", "audio", "blockquote", "canvas", "center", "details", "dialog", "div",
        "dl", "embed", "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6",
        "header", "hr", "iframe", "main", "nav", "noscript", "object", "ol", "p", "picture", "pre", "script",
        "section", "style", "table", "ul", "video",
    ]

    /// Replaces the selection with `html`. Block-level HTML (starting with
    /// e.g. `<div>`, `<figure>` or `<iframe>`) gets empty lines around it,
    /// which Markdown needs to treat it as HTML.
    public static func insertHTML(_ html: String, in text: String, selection: NSRange) -> FormattingEdit {
        let ns = text as NSString
        let body = html.trimmingCharacters(in: .whitespacesAndNewlines)
        var replacement = body
        if isBlockHTML(body) {
            let before = ns.substring(to: selection.location)
            let after = ns.substring(from: NSMaxRange(selection))
            if !before.isEmpty {
                let trailing = before.reversed().prefix { $0 == "\n" }.count
                replacement = String(repeating: "\n", count: max(0, 2 - trailing)) + replacement
            }
            let leading = after.prefix { $0 == "\n" }.count
            replacement += String(repeating: "\n", count: after.isEmpty ? 1 : max(0, 2 - leading))
        }
        let caret = selection.location + (replacement as NSString).length
        return FormattingEdit(range: selection, replacement: replacement, selection: NSRange(location: caret, length: 0))
    }

    static func isBlockHTML(_ html: String) -> Bool {
        guard let match = html.range(of: #"^<([A-Za-z][A-Za-z0-9]*)"#, options: .regularExpression) else { return false }
        let name = html[match].dropFirst().lowercased()
        return blockTags.contains(name)
    }

    // MARK: Helpers

    private static func isMarker(_ char: Character) -> Bool { char == "*" || char == "_" }

    private static func character(at index: Int, in ns: NSString) -> Character? {
        guard index >= 0, index < ns.length else { return nil }
        return Character(ns.substring(with: NSRange(location: index, length: 1)))
    }

    private static func character(before index: Int, in ns: NSString) -> Character? {
        character(at: index - 1, in: ns)
    }

    private static func run(of char: Character, endingAt end: Int, in ns: NSString) -> Int {
        var count = 0
        while character(at: end - count - 1, in: ns) == char { count += 1 }
        return count
    }

    private static func run(of char: Character, startingAt start: Int, in ns: NSString) -> Int {
        var count = 0
        while character(at: start + count, in: ns) == char { count += 1 }
        return count
    }

    private static func trimmingWhitespace(_ range: NSRange, in ns: NSString) -> NSRange {
        var range = range
        while range.length > 0, let char = character(at: range.location, in: ns), char.isWhitespace {
            range.location += 1
            range.length -= 1
        }
        while range.length > 0, let char = character(at: NSMaxRange(range) - 1, in: ns), char.isWhitespace {
            range.length -= 1
        }
        return range
    }

    /// The word around `location`, or an empty range there if the caret is
    /// not in or next to a word.
    private static func word(at location: Int, in ns: NSString) -> NSRange {
        let isWordCharacter = { (char: Character?) in char.map { $0.isLetter || $0.isNumber || $0 == "'" } ?? false }
        var start = location
        var end = location
        while isWordCharacter(character(at: start - 1, in: ns)) { start -= 1 }
        while isWordCharacter(character(at: end, in: ns)) { end += 1 }
        return NSRange(location: start, length: end - start)
    }
}
