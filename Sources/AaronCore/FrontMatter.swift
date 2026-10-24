import Foundation

/// A metadata block at the start of a document: Pelican/MultiMarkdown style
/// `Key: value` lines ended by a blank line, or YAML between `---` lines.
/// All ranges are UTF-16 ranges into the parsed text.
public struct FrontMatter: Equatable, Sendable {
    public enum Style: Equatable, Sendable { case pelican, yaml }

    public struct Field: Equatable, Sendable {
        public var key: String
        public var value: String
        public var keyRange: NSRange
        public var valueRange: NSRange
        /// The field's first line, without the line ending.
        public var lineRange: NSRange
    }

    public var style: Style
    public var fields: [Field]
    /// Range of the whole block including the separating blank line.
    public var range: NSRange
    public var bodyStart: Int { NSMaxRange(range) }

    public func field(named key: String) -> Field? {
        fields.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }
    }

    public func value(for key: String) -> String? {
        field(named: key)?.value
    }

    public static func parse(_ text: String) -> FrontMatter? {
        let lines = Line.split(text as NSString)
        guard let first = lines.first else { return nil }
        if first.content == "---" {
            return parseYAML(lines)
        }
        return parsePelican(lines)
    }

    private static let keyPattern = try! NSRegularExpression(
        pattern: #"^([A-Za-z][A-Za-z0-9_-]*):(?:[ \t]+|$)"#)

    private static func field(in line: Line) -> Field? {
        let content = line.content as NSString
        guard let match = keyPattern.firstMatch(
            in: line.content, range: NSRange(location: 0, length: content.length)) else { return nil }
        let keyRange = match.range(at: 1)
        let valueStart = NSMaxRange(match.range)
        var valueEnd = content.length
        while valueEnd > valueStart,
              let scalar = UnicodeScalar(content.character(at: valueEnd - 1)),
              CharacterSet.whitespaces.contains(scalar) {
            valueEnd -= 1
        }
        let valueRange = NSRange(location: valueStart, length: valueEnd - valueStart)
        return Field(
            key: content.substring(with: keyRange),
            value: content.substring(with: valueRange),
            keyRange: NSRange(location: line.range.location + keyRange.location, length: keyRange.length),
            valueRange: NSRange(location: line.range.location + valueRange.location, length: valueRange.length),
            lineRange: line.range)
    }

    private static func parsePelican(_ lines: [Line]) -> FrontMatter? {
        var fields: [Field] = []
        var end = 0
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if let field = field(in: line) {
                fields.append(field)
            } else if !fields.isEmpty, line.isContinuation {
                fields[fields.count - 1].value += " " + line.content.trimmingCharacters(in: .whitespaces)
            } else {
                break
            }
            end = NSMaxRange(line.fullRange)
            index += 1
        }
        guard !fields.isEmpty else { return nil }
        if index < lines.count, lines[index].isBlank {
            end = NSMaxRange(lines[index].fullRange)
        }
        return FrontMatter(style: .pelican, fields: fields, range: NSRange(location: 0, length: end))
    }

    private static func parseYAML(_ lines: [Line]) -> FrontMatter? {
        var fields: [Field] = []
        for index in lines.indices.dropFirst() {
            let line = lines[index]
            if line.content == "---" || line.content == "..." {
                var end = NSMaxRange(line.fullRange)
                if index + 1 < lines.count, lines[index + 1].isBlank {
                    end = NSMaxRange(lines[index + 1].fullRange)
                }
                return FrontMatter(style: .yaml, fields: fields, range: NSRange(location: 0, length: end))
            }
            if let field = field(in: line) { fields.append(field) }
        }
        return nil
    }
}

/// A line of text with and without its line ending.
struct Line {
    var content: String
    /// Range without the line terminator.
    var range: NSRange
    /// Range including the line terminator.
    var fullRange: NSRange

    var isBlank: Bool { content.trimmingCharacters(in: .whitespaces).isEmpty }
    var isContinuation: Bool { content.hasPrefix("    ") || content.hasPrefix("\t") }

    static func split(_ text: NSString) -> [Line] {
        var lines: [Line] = []
        var start = 0
        while start < text.length {
            var lineEnd = 0, contentsEnd = 0
            text.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd,
                              for: NSRange(location: start, length: 0))
            let range = NSRange(location: start, length: contentsEnd - start)
            lines.append(Line(content: text.substring(with: range), range: range,
                              fullRange: NSRange(location: start, length: lineEnd - start)))
            start = lineEnd
        }
        return lines
    }
}
