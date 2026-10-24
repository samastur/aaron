import Foundation

/// A replacement of `range` (UTF-16) in the document with `replacement`.
public struct TextEdit: Equatable, Sendable {
    public var range: NSRange
    public var replacement: String

    public init(range: NSRange, replacement: String) {
        self.range = range
        self.replacement = replacement
    }

    /// The edit described by `NSTextStorage` after processing: `editedRange`
    /// is the range of the new text, `changeInLength` the length difference.
    public init(storageEditedRange editedRange: NSRange, changeInLength: Int, newText: String) {
        let replacement = (newText as NSString).substring(with: editedRange)
        self.init(range: NSRange(location: editedRange.location, length: editedRange.length - changeInLength),
                  replacement: replacement)
    }

    /// How much the document length changes when this edit is applied.
    public var delta: Int { (replacement as NSString).length - range.length }
}

public struct Suggestion: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        /// Located in the text and waiting for a decision.
        case open
        case accepted
        case dismissed
        /// The text it refers to was edited; it can only be dismissed.
        case stale
        /// The quoted text does not occur in the document.
        case notFound
        /// The quoted text occurs in several places and context did not decide.
        case ambiguous
    }

    public let id: UUID
    public var actionName: String
    public var original: String
    public var replacement: String?
    public var message: String
    public var category: String?
    public var range: NSRange?
    public var status: Status

    public init(id: UUID = UUID(), actionName: String, original: String, replacement: String?,
                message: String, category: String?, range: NSRange?, status: Status) {
        self.id = id
        self.actionName = actionName
        self.original = original
        self.replacement = replacement
        self.message = message
        self.category = category
        self.range = range
        self.status = status
    }

    public var isComment: Bool { replacement == nil }
    public var canAccept: Bool { status == .open && replacement != nil }
}

/// State of review mode: the suggestions gathered by AI actions and their
/// positions in the current text.
public struct ReviewSession: Equatable, Sendable {
    public private(set) var suggestions: [Suggestion] = []

    public init() {}

    public var openSuggestions: [Suggestion] {
        suggestions.filter { $0.status == .open }
    }

    /// Open, located suggestions in document order.
    public var highlights: [Suggestion] {
        openSuggestions
            .filter { $0.range != nil }
            .sorted { $0.range!.location < $1.range!.location }
    }

    public mutating func add(_ raws: [RawSuggestion], actionName: String, text: String) {
        for raw in raws {
            var range: NSRange?
            let status: Suggestion.Status
            switch QuoteResolver.resolve(raw.quotation, in: text) {
            case .resolved(let found):
                range = found
                status = .open
            case .notFound:
                status = .notFound
            case .ambiguous:
                status = .ambiguous
            }
            suggestions.append(Suggestion(
                actionName: actionName, original: raw.original,
                replacement: raw.replacement, message: raw.message,
                category: raw.category, range: range, status: status))
        }
    }

    public func suggestion(withID id: UUID) -> Suggestion? {
        suggestions.first { $0.id == id }
    }

    /// Marks the suggestion accepted and returns the edit to apply, after
    /// checking that the text at its range is still what was quoted.
    public mutating func accept(_ id: UUID, in text: String) -> TextEdit? {
        guard let index = suggestions.firstIndex(where: { $0.id == id }),
              suggestions[index].canAccept,
              let range = suggestions[index].range,
              let replacement = suggestions[index].replacement else { return nil }
        let current = text as NSString
        guard NSMaxRange(range) <= current.length,
              current.substring(with: range) == suggestions[index].original else {
            markStale(index)
            return nil
        }
        suggestions[index].status = .accepted
        suggestions[index].range = nil
        return TextEdit(range: range, replacement: replacement)
    }

    public mutating func dismiss(_ id: UUID) {
        guard let index = suggestions.firstIndex(where: { $0.id == id }) else { return }
        suggestions[index].status = .dismissed
        suggestions[index].range = nil
    }

    public mutating func clear() {
        suggestions.removeAll()
    }

    /// Updates ranges after the document was edited: later suggestions move,
    /// earlier ones stay, overlapping ones become stale.
    public mutating func applyEdit(_ edit: TextEdit) {
        let editEnd = NSMaxRange(edit.range)
        for index in suggestions.indices {
            guard suggestions[index].status == .open, let range = suggestions[index].range else { continue }
            if NSMaxRange(range) <= edit.range.location {
                continue
            } else if range.location >= editEnd {
                suggestions[index].range = NSRange(location: range.location + edit.delta, length: range.length)
            } else {
                markStale(index)
            }
        }
    }

    /// The open suggestion covering `location`, preferring the shortest one.
    public func suggestion(at location: Int) -> Suggestion? {
        highlights
            .filter { location >= $0.range!.location && location < NSMaxRange($0.range!) }
            .min { $0.range!.length < $1.range!.length }
    }

    /// The next open, located suggestion in document order, wrapping around.
    public func nextOpen(after id: UUID?) -> Suggestion? {
        let ordered = highlights
        guard let id, let current = ordered.firstIndex(where: { $0.id == id }) else {
            return ordered.first
        }
        return ordered[(current + 1) % ordered.count]
    }

    private mutating func markStale(_ index: Int) {
        suggestions[index].status = .stale
        suggestions[index].range = nil
    }
}
