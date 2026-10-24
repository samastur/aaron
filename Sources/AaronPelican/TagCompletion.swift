import AaronCore
import Foundation

/// Tag autocompletion on the `Tags:` metadata line.
public enum TagCompletion {
    public struct Context: Equatable, Sendable {
        /// Text to replace with the chosen tag (from the tag's start to the caret).
        public var replaceRange: NSRange
        public var partial: String
        /// Other tags already on the line.
        public var existing: [String]
        /// The caret is directly after `Tags:`; insert a space before the tag.
        public var needsLeadingSpace: Bool
    }

    public static func context(in text: String, caret: Int, field: String = "Tags") -> Context? {
        guard let frontMatter = FrontMatter.parse(text),
              let tagsField = frontMatter.field(named: field) else { return nil }
        let ns = text as NSString
        let line = tagsField.lineRange
        let valueStart = NSMaxRange(tagsField.keyRange) + 1  // after the colon
        guard caret >= valueStart, caret <= NSMaxRange(line) else { return nil }

        let afterColon = NSRange(location: valueStart, length: NSMaxRange(line) - valueStart)
        let value = ns.substring(with: afterColon) as NSString
        let caretInValue = caret - valueStart

        // Find the comma-separated token around the caret.
        let before = value.substring(to: caretInValue) as NSString
        let lastComma = before.range(of: ",", options: .backwards)
        var tokenStart = lastComma.location == NSNotFound ? 0 : NSMaxRange(lastComma)
        while tokenStart < caretInValue, value.character(at: tokenStart) == 0x20 || value.character(at: tokenStart) == 0x09 {
            tokenStart += 1
        }
        let partialRange = NSRange(location: tokenStart, length: caretInValue - tokenStart)
        let partial = value.substring(with: partialRange)

        // All tokens except the one being edited.
        var existing: [String] = []
        var offset = 0
        for token in (value as String).components(separatedBy: ",") {
            let length = (token as NSString).length
            let containsCaret = caretInValue >= offset && caretInValue <= offset + length
            let name = token.trimmingCharacters(in: .whitespaces)
            if !containsCaret, !name.isEmpty { existing.append(name) }
            offset += length + 1
        }

        return Context(
            replaceRange: NSRange(location: valueStart + tokenStart, length: partialRange.length),
            partial: partial,
            existing: existing,
            needsLeadingSpace: caret == valueStart && caretInValue == 0)
    }

    /// Matching tag names: prefix matches first, then matches at the start of
    /// a later word, then other substring matches; by usage within each group.
    public static func candidates(for partial: String, in tags: [TagInfo], excluding existing: [String]) -> [String] {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let excluded = Set(existing.map { $0.folding(options: options, locale: nil) })
        let needle = partial.trimmingCharacters(in: .whitespaces).folding(options: options, locale: nil)

        func rank(_ tag: TagInfo) -> Int? {
            let name = tag.name.folding(options: options, locale: nil)
            if excluded.contains(name) { return nil }
            if needle.isEmpty || name.hasPrefix(needle) { return 0 }
            if name.split(separator: " ").dropFirst().contains(where: { $0.hasPrefix(needle) }) { return 1 }
            if name.contains(needle) { return 2 }
            return nil
        }

        return tags
            .compactMap { tag in rank(tag).map { (tag, $0) } }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                if lhs.0.count != rhs.0.count { return lhs.0.count > rhs.0.count }
                return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
            }
            .map(\.0.name)
    }
}
