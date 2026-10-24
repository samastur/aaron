import Foundation

/// A passage identified by quoting it, optionally with the text immediately
/// before (`prefix`) and after (`suffix`) it.
public struct Quotation: Equatable, Sendable {
    public var original: String
    public var prefix: String?
    public var suffix: String?

    public init(original: String, prefix: String?, suffix: String?) {
        self.original = original
        self.prefix = prefix
        self.suffix = suffix
    }
}

public enum QuoteResolution: Equatable, Sendable {
    case resolved(NSRange)
    case notFound
    case ambiguous(count: Int)
}

/// Resolves quotations to UTF-16 ranges deterministically. It never guesses
/// between several equally good candidates.
public enum QuoteResolver {
    public static func resolve(_ quote: Quotation, in document: String) -> QuoteResolution {
        let text = document as NSString
        let occurrences = occurrences(of: quote.original, in: text)
        guard !occurrences.isEmpty else { return .notFound }

        let matching = occurrences.filter { range in
            contextMatches(quote, around: range, in: text)
        }
        if matching.count == 1 { return .resolved(matching[0]) }
        if matching.isEmpty, occurrences.count == 1 { return .resolved(occurrences[0]) }
        return .ambiguous(count: matching.isEmpty ? occurrences.count : matching.count)
    }

    static func occurrences(of needle: String, in text: NSString) -> [NSRange] {
        guard !needle.isEmpty else { return [] }
        var found: [NSRange] = []
        var start = 0
        while start < text.length {
            let match = text.range(of: needle, options: .literal,
                                   range: NSRange(location: start, length: text.length - start))
            if match.location == NSNotFound { break }
            found.append(match)
            // Advance by one UTF-16 unit (or a whole surrogate pair) so overlapping matches count.
            start = match.location + text.rangeOfComposedCharacterSequence(at: match.location).length
        }
        return found
    }

    private static func contextMatches(_ quote: Quotation, around range: NSRange, in text: NSString) -> Bool {
        if let prefix = quote.prefix, !prefix.isEmpty {
            let before = text.substring(to: range.location)
            if !before.hasSuffix(prefix) { return false }
        }
        if let suffix = quote.suffix, !suffix.isEmpty {
            let after = text.substring(from: NSMaxRange(range))
            if !after.hasPrefix(suffix) { return false }
        }
        return true
    }
}
