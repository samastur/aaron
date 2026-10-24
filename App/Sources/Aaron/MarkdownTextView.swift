import AaronPelican
import AppKit

/// The editor's text view. Adds tag completion on the Pelican `Tags:` line
/// through the standard NSTextView completion mechanism (Esc / ⌥⎋), and
/// opens it automatically while a tag is being typed.
final class MarkdownTextView: NSTextView {
    var tagCompletionSource: () -> [TagInfo] = { [] }
    var isTagCompletionEnabled: () -> Bool = { false }

    private var isInsertingCompletion = false

    private var tagContext: TagCompletion.Context? {
        guard isTagCompletionEnabled() else { return nil }
        let selection = selectedRange()
        return TagCompletion.context(in: string, caret: selection.location + selection.length)
    }

    override var rangeForUserCompletion: NSRange {
        tagContext?.replaceRange ?? super.rangeForUserCompletion
    }

    override func completions(forPartialWordRange charRange: NSRange,
                              indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {
        guard let context = tagContext else {
            return super.completions(forPartialWordRange: charRange, indexOfSelectedItem: index)
        }
        let candidates = TagCompletion.candidates(for: context.partial, in: tagCompletionSource(),
                                                  excluding: context.existing)
        index.pointee = context.partial.isEmpty ? -1 : 0
        return context.needsLeadingSpace ? candidates.map { " " + $0 } : candidates
    }

    override func insertCompletion(_ word: String, forPartialWordRange charRange: NSRange,
                                   movement: Int, isFinal flag: Bool) {
        isInsertingCompletion = true
        defer { isInsertingCompletion = false }
        super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: flag)
    }

    /// Opens the completion list while a tag is being typed.
    func autoCompleteTagIfNeeded() {
        guard !isInsertingCompletion, let context = tagContext, !context.partial.isEmpty else { return }
        let candidates = TagCompletion.candidates(for: context.partial, in: tagCompletionSource(),
                                                  excluding: context.existing)
        guard !candidates.isEmpty else { return }
        // Not if the only candidate is exactly what was typed.
        if candidates.count == 1, candidates[0].caseInsensitiveCompare(context.partial) == .orderedSame { return }
        DispatchQueue.main.async { [weak self] in
            self?.complete(nil)
        }
    }
}
