import Foundation

/// A suggestion as reported by the AI, before it is located in the text.
public struct RawSuggestion: Equatable, Sendable, Decodable {
    public var original: String
    public var prefix: String?
    public var suffix: String?
    public var replacement: String?
    public var message: String
    public var category: String?

    public init(original: String, prefix: String?, suffix: String?,
                replacement: String?, message: String, category: String?) {
        self.original = original
        self.prefix = prefix
        self.suffix = suffix
        self.replacement = replacement
        self.message = message
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case original, prefix, suffix, replacement, message, category
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        original = try container.decode(String.self, forKey: .original)
        prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
        suffix = try container.decodeIfPresent(String.self, forKey: .suffix)
        replacement = try container.decodeIfPresent(String.self, forKey: .replacement)
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category)
    }

    public var quotation: Quotation {
        Quotation(original: original, prefix: prefix, suffix: suffix)
    }
}

/// Finds the suggestion payload in whatever an AI command printed: bare
/// JSON, JSON in a Markdown fence or surrounded by prose, or Claude Code's
/// `--output-format json` wrapper.
public enum ResponseExtractor {
    public enum ExtractionError: Error, Equatable {
        case noSuggestions
    }

    private struct Envelope: Decodable {
        var suggestions: [RawSuggestion]
    }

    private struct ResultWrapper: Decodable {
        var result: String
    }

    public static func suggestions(from output: String) throws -> [RawSuggestion] {
        if let found = search(output, depth: 0) { return found }
        throw ExtractionError.noSuggestions
    }

    private static func search(_ text: String, depth: Int) -> [RawSuggestion]? {
        let decoder = JSONDecoder()
        for candidate in jsonCandidates(in: text) {
            let data = Data(candidate.utf8)
            if let envelope = try? decoder.decode(Envelope.self, from: data) {
                return envelope.suggestions
            }
            if let list = try? decoder.decode([RawSuggestion].self, from: data) {
                return list
            }
            if depth == 0, let wrapper = try? decoder.decode(ResultWrapper.self, from: data),
               let inner = search(wrapper.result, depth: depth + 1) {
                return inner
            }
        }
        return nil
    }

    /// Balanced `{…}` / `[…]` substrings in order of their start, aware of
    /// JSON string literals so braces inside strings are ignored.
    static func jsonCandidates(in text: String) -> [String] {
        let chars = Array(text.unicodeScalars)
        var result: [String] = []
        var start = 0
        while start < chars.count {
            let c = chars[start]
            if c == "{" || c == "[", let end = matchingEnd(chars, from: start) {
                var scalars = String.UnicodeScalarView()
                scalars.append(contentsOf: chars[start...end])
                result.append(String(scalars))
            }
            start += 1
        }
        return result
    }

    private static func matchingEnd(_ chars: [Unicode.Scalar], from start: Int) -> Int? {
        var stack: [Unicode.Scalar] = []
        var inString = false
        var escaped = false
        var i = start
        while i < chars.count {
            let c = chars[i]
            if inString {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
            } else {
                switch c {
                case "\"": inString = true
                case "{": stack.append("}")
                case "[": stack.append("]")
                case "}", "]":
                    guard stack.popLast() == c else { return nil }
                    if stack.isEmpty { return i }
                default: break
                }
            }
            i += 1
        }
        return nil
    }
}
