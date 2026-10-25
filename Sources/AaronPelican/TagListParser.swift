import Foundation

public struct TagInfo: Equatable, Sendable {
    public var name: String
    /// How many posts use the tag; 0 when unknown.
    public var count: Int

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

/// Parses the output of the configured tag command. Accepted formats:
/// `{"tags": [{"name": …, "count": …}]}` (a tag-listing
/// script's JSON output), a JSON array of names or such objects, or plain text with one
/// tag per line, optionally preceded by its count.
public enum TagListParser {
    public static func parse(_ output: String) throws -> [TagInfo] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        let parsed: [TagInfo]
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            parsed = try parseJSON(trimmed)
        } else {
            parsed = parseLines(trimmed)
        }
        return merged(parsed)
    }

    private static func parseJSON(_ text: String) throws -> [TagInfo] {
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8))
        let list: [Any]
        if let dict = object as? [String: Any] {
            list = dict["tags"] as? [Any] ?? []
        } else {
            list = object as? [Any] ?? []
        }
        return list.compactMap { item in
            if let name = item as? String { return TagInfo(name: name, count: 0) }
            if let dict = item as? [String: Any], let name = dict["name"] as? String {
                return TagInfo(name: name, count: (dict["count"] as? Int) ?? 0)
            }
            return nil
        }
    }

    private static func parseLines(_ text: String) -> [TagInfo] {
        text.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            if parts.count == 2, let count = Int(parts[0]) {
                return TagInfo(name: parts[1].trimmingCharacters(in: .whitespaces), count: count)
            }
            return TagInfo(name: line, count: 0)
        }
    }

    /// Removes case-insensitive duplicates, keeping the first spelling and
    /// the highest count.
    private static func merged(_ tags: [TagInfo]) -> [TagInfo] {
        var result: [TagInfo] = []
        var index: [String: Int] = [:]
        for tag in tags where !tag.name.isEmpty {
            let key = tag.name.lowercased()
            if let existing = index[key] {
                result[existing].count = max(result[existing].count, tag.count)
            } else {
                index[key] = result.count
                result.append(tag)
            }
        }
        return result
    }
}
