import AaronAI
import AaronCore
import AaronPelican
import AppKit
import SwiftUI

/// Gives the window model access to the window's text view.
@MainActor
final class EditorController {
    weak var textView: MarkdownTextView?

    var currentText: String { textView?.string ?? "" }
    var selectedRange: NSRange { textView?.selectedRange() ?? NSRange(location: 0, length: 0) }

    func setEditable(_ editable: Bool) {
        textView?.isEditable = editable
    }

    /// Applies an edit as an undoable user change.
    @discardableResult
    func apply(_ edit: TextEdit, undoName: String) -> Bool {
        guard let textView, let storage = textView.textStorage,
              NSMaxRange(edit.range) <= storage.length,
              textView.shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return false }
        storage.replaceCharacters(in: edit.range, with: edit.replacement)
        textView.didChangeText()
        textView.undoManager?.setActionName(undoName)
        let inserted = NSRange(location: edit.range.location, length: (edit.replacement as NSString).length)
        textView.setSelectedRange(inserted)
        textView.scrollRangeToVisible(inserted)
        return true
    }

    func reveal(_ range: NSRange) {
        guard let textView, NSMaxRange(range) <= (textView.string as NSString).length else { return }
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.showFindIndicator(for: range)
    }

    func focus() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }
}

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    let model: DocumentWindowModel
    let settings: EditorSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, model: model)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // TextKit 1 stack: lets suggestion highlights use temporary attributes.
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = MarkdownTextView(frame: .zero, textContainer: container)
        textView.setAccessibilityIdentifier("editor")
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 24, height: 20)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView

        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.settings = settings
        textView.delegate = coordinator
        storage.delegate = coordinator
        textView.tagCompletionSource = { [weak coordinator] in coordinator?.model.tags ?? [] }
        textView.isTagCompletionEnabled = { [weak coordinator] in coordinator?.model.isPelican ?? false }
        model.editor.textView = textView

        textView.string = text
        coordinator.applySyntaxHighlighting()
        textView.typingAttributes = coordinator.styles.base
        DispatchQueue.main.async {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let textView = coordinator.textView else { return }
        if coordinator.settings != settings {
            coordinator.settings = settings
            coordinator.applySyntaxHighlighting()
        }
        if textView.string != text {
            // The document changed outside the editor, e.g. File ▸ Revert.
            // Deferred: replacing the text updates the model, which must not
            // happen during a view update.
            DispatchQueue.main.async {
                guard textView.string != coordinator.text.wrappedValue else { return }
                textView.string = coordinator.text.wrappedValue
                coordinator.applySyntaxHighlighting()
                coordinator.model.textChanged(textView.string)
            }
        }
        textView.isEditable = !model.isRunningAction
        coordinator.applySuggestionHighlights(model.session.highlights, selected: model.selectedSuggestionID)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var text: Binding<String>
        let model: DocumentWindowModel
        weak var textView: MarkdownTextView?
        var settings = EditorSettings() {
            didSet { styles = EditorStyles(settings: settings) }
        }
        private(set) var styles = EditorStyles(settings: EditorSettings())
        private var lastEditWasTypedCharacter = false

        init(text: Binding<String>, model: DocumentWindowModel) {
            self.text = text
            self.model = model
        }

        // Every character change, from typing, undo, paste or accepting a suggestion.
        nonisolated func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                                     range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            let edit = TextEdit(storageEditedRange: editedRange, changeInLength: delta, newText: textStorage.string)
            MainActor.assumeIsolated {
                lastEditWasTypedCharacter = edit.range.length == 0 && (edit.replacement as NSString).length == 1
                model.recordEdit(edit)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text.wrappedValue = textView.string
            model.textChanged(textView.string)
            if !textView.hasMarkedText() {
                applySyntaxHighlighting()
            }
            if lastEditWasTypedCharacter {
                textView.autoCompleteTagIfNeeded()
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            let selection = textView.selectedRange()
            if selection.length == 0 {
                model.caretMoved(to: selection.location)
            }
        }

        func applySyntaxHighlighting() {
            guard let textView, let storage = textView.textStorage else { return }
            let full = NSRange(location: 0, length: storage.length)
            let runs = MarkdownHighlighter.runs(in: storage.string)
            storage.beginEditing()
            storage.setAttributes(styles.base, range: full)
            for run in runs {
                storage.addAttributes(styles.attributes(for: run, in: storage.string as NSString), range: run.range)
            }
            storage.endEditing()
            textView.typingAttributes = styles.base
        }

        func applySuggestionHighlights(_ highlights: [Suggestion], selected: UUID?) {
            guard let textView, let layoutManager = textView.layoutManager else { return }
            let length = (textView.string as NSString).length
            let full = NSRange(location: 0, length: length)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
            layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: full)
            layoutManager.removeTemporaryAttribute(.underlineColor, forCharacterRange: full)
            for suggestion in highlights {
                guard let range = suggestion.range, NSMaxRange(range) <= length else { continue }
                let isSelected = suggestion.id == selected
                let color = EditorStyles.suggestionColor(suggestion)
                layoutManager.addTemporaryAttributes([
                    .backgroundColor: color.withAlphaComponent(isSelected ? 0.38 : 0.16),
                    .underlineStyle: NSUnderlineStyle.thick.rawValue,
                    .underlineColor: color,
                ], forCharacterRange: range)
            }
        }
    }
}

/// Fonts and colours used by the editor's syntax highlighting.
@MainActor
struct EditorStyles {
    let base: [NSAttributedString.Key: Any]
    let font: NSFont
    let monoFont: NSFont

    init(settings: EditorSettings) {
        let size = CGFloat(settings.effectiveFontSize)
        font = settings.monospaced ? .monospacedSystemFont(ofSize: size, weight: .regular) : .systemFont(ofSize: size)
        monoFont = .monospacedSystemFont(ofSize: size * 0.92, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.25
        paragraph.paragraphSpacing = size * 0.3
        base = [.font: font, .foregroundColor: NSColor.textColor, .paragraphStyle: paragraph]
    }

    func attributes(for run: StyleRun, in text: NSString) -> [NSAttributedString.Key: Any] {
        let manager = NSFontManager.shared
        switch run.kind {
        case .heading:
            let level = text.substring(with: run.range).prefix { $0 == "#" }.count
            let scale: CGFloat = [1.45, 1.3, 1.15, 1.05, 1.0, 1.0][max(0, min(level - 1, 5))]
            let heading = NSFont.systemFont(ofSize: font.pointSize * scale, weight: .bold)
            return [.font: heading]
        case .strong:
            return [.font: manager.convert(font, toHaveTrait: .boldFontMask)]
        case .emphasis:
            return [.font: manager.convert(font, toHaveTrait: .italicFontMask)]
        case .code, .codeBlock:
            return [.font: monoFont, .foregroundColor: NSColor.systemPurple]
        case .linkText:
            return [.foregroundColor: NSColor.linkColor]
        case .linkURL:
            return [.foregroundColor: NSColor.secondaryLabelColor]
        case .quote:
            return [.foregroundColor: NSColor.secondaryLabelColor]
        case .listMarker:
            return [.foregroundColor: NSColor.systemOrange]
        case .metadataKey:
            return [.foregroundColor: NSColor.systemTeal, .font: manager.convert(font, toHaveTrait: .boldFontMask)]
        case .metadataValue:
            return [.foregroundColor: NSColor.secondaryLabelColor]
        }
    }

    static func suggestionColor(_ suggestion: Suggestion) -> NSColor {
        suggestion.isComment ? .systemBlue : .systemOrange
    }
}
