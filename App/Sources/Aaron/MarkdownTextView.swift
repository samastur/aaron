import AaronCore
import AaronPelican
import AppKit

/// The editor's text view. Adds tag completion on the Pelican `Tags:` line
/// through the standard NSTextView completion mechanism (Esc / ⌥⎋), and
/// opens it automatically while a tag is being typed.
final class MarkdownTextView: NSTextView {
    var tagCompletionSource: () -> [TagInfo] = { [] }
    var isTagCompletionEnabled: () -> Bool = { false }

    private var isInsertingCompletion = false
    /// The latest change came from the keyboard (not paste, undo or completion).
    private(set) var lastChangeWasTyping = false

    #if DEBUG
    /// Set by the debug harness: count automatic completion instead of
    /// opening the (modal) completion list.
    var debugSuppressCompletionPopup = false
    private(set) var debugAutoCompletionCount = 0

    /// The tag candidates the completion list would show right now.
    var debugTagCandidates: [String]? {
        guard let context = tagContext else { return nil }
        return TagCompletion.candidates(for: context.partial, in: tagCompletionSource(), excluding: context.existing)
    }
    #endif

    private var tagContext: TagCompletion.Context? {
        guard isTagCompletionEnabled() else { return nil }
        let selection = selectedRange()
        return TagCompletion.context(in: string, caret: selection.location + selection.length)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        // Typing over an inline completion replaces the selected suggestion,
        // so this can't be inferred from the shape of the edit.
        lastChangeWasTyping = !isInsertingCompletion
        defer { lastChangeWasTyping = false }
        super.insertText(string, replacementRange: replacementRange)
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

    // MARK: Format menu

    @objc func toggleMarkdownBold(_ sender: Any?) {
        applyFormatting(MarkdownFormatting.toggleBold(in: string, selection: selectedRange()), undoName: "Bold")
    }

    @objc func toggleMarkdownItalic(_ sender: Any?) {
        applyFormatting(MarkdownFormatting.toggleItalic(in: string, selection: selectedRange()), undoName: "Italic")
    }

    @objc func insertMarkdownLink(_ sender: Any?) {
        let clipboard = NSPasteboard.general.string(forType: .string)
        applyFormatting(MarkdownFormatting.insertLink(in: string, selection: selectedRange(), clipboardURL: clipboard),
                        undoName: "Link")
    }

    @objc func toggleMarkdownQuote(_ sender: Any?) {
        applyFormatting(MarkdownFormatting.toggleQuote(in: string, selection: selectedRange()), undoName: "Quote")
    }

    /// Asks for HTML to paste and inserts it in place of the selection.
    @objc func insertHTMLFromDialog(_ sender: Any?) {
        guard isEditable, let window else { NSSound.beep(); return }
        let alert = NSAlert()
        alert.messageText = "Insert HTML"
        alert.informativeText = "Paste the HTML to insert, e.g. an embed code."
        alert.addButton(withTitle: "Insert")
        alert.addButton(withTitle: "Cancel")

        let scrollView = NSTextView.scrollableTextView()
        scrollView.frame = NSRect(x: 0, y: 0, width: 420, height: 180)
        scrollView.borderType = .bezelBorder
        let input = scrollView.documentView as! NSTextView
        input.isRichText = false
        input.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        input.isAutomaticQuoteSubstitutionEnabled = false
        input.isAutomaticDashSubstitutionEnabled = false
        input.isAutomaticTextReplacementEnabled = false
        input.isAutomaticSpellingCorrectionEnabled = false
        input.setAccessibilityIdentifier("htmlInput")
        alert.accessoryView = scrollView
        alert.window.initialFirstResponder = input

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            self.insertHTMLFragment(input.string)
        }
    }

    func insertHTMLFragment(_ html: String) {
        guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        applyFormatting(MarkdownFormatting.insertHTML(html, in: string, selection: selectedRange()),
                        undoName: "Insert HTML")
    }

    /// Applies a Format command as one undoable change.
    private func applyFormatting(_ edit: FormattingEdit, undoName: String) {
        guard isEditable, let storage = textStorage, NSMaxRange(edit.range) <= storage.length else {
            NSSound.beep()
            return
        }
        window?.makeFirstResponder(self)
        guard shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
        storage.replaceCharacters(in: edit.range, with: edit.replacement)
        didChangeText()
        undoManager?.setActionName(undoName)
        setSelectedRange(edit.selection)
        scrollRangeToVisible(edit.selection)
    }

    /// Opens the completion list while a tag is being typed.
    func autoCompleteTagIfNeeded() {
        guard !isInsertingCompletion, let context = tagContext, !context.partial.isEmpty else { return }
        let candidates = TagCompletion.candidates(for: context.partial, in: tagCompletionSource(),
                                                  excluding: context.existing)
        guard !candidates.isEmpty else { return }
        // Not if the only candidate is exactly what was typed.
        if candidates.count == 1, candidates[0].caseInsensitiveCompare(context.partial) == .orderedSame { return }
        #if DEBUG
        debugAutoCompletionCount += 1
        if debugSuppressCompletionPopup { return }
        #endif
        DispatchQueue.main.async { [weak self] in
            self?.complete(nil)
        }
    }
}
