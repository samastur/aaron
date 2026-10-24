#if DEBUG
import AaronAI
import AppKit
import SwiftUI
import WebKit

/// Debug builds only: drives the first document window from a JSON script
/// and records snapshots, for checking the app without UI automation
/// permissions. See docs/developer/testing.md.
///
/// AARON_DEBUG_SCRIPT=steps.json AARON_SNAPSHOT_DIR=out/ Aaron.app/Contents/MacOS/Aaron file.md
@MainActor
enum DebugHarness {
    struct Step: Decodable {
        var wait: Double?
        var type: String?
        var caretAfter: String?
        var caretAtEnd: Bool?
        var complete: Bool?
        var run: String?
        var waitIdle: Bool?
        var cancel: Bool?
        var accept: Int?
        var dismiss: Int?
        var undo: Bool?
        var renderer: String?
        var preview: Bool?
        var review: Bool?
        var snapshot: String?
        var expect: Expectation?
        var quit: Bool?
    }

    /// Checks of the window's state; every given field must match.
    struct Expectation: Decodable {
        var text: String?
        var textContains: String?
        var textLacks: String?
        var isPelican: Bool?
        var isEditable: Bool?
        var renderer: String?
        var previewContains: String?
        var previewError: Bool?
        var aiError: Bool?
        var aiNotice: String?
        var tagCount: Int?
        var tagCandidatesStartWith: [String]?
        var autoCompletionRequested: Bool?
        var statuses: [String: Int]?
        var selectedSuggestion: String?
        var showReview: Bool?
        var words: Int?
    }

    private static var failures: [String] = []

    static weak var previewWebView: WKWebView?
    private static var started = false

    static func attach(_ model: DocumentWindowModel) {
        let env = ProcessInfo.processInfo.environment
        guard !started, let scriptPath = env["AARON_DEBUG_SCRIPT"] else { return }
        started = true
        let output = URL(fileURLWithPath: env["AARON_SNAPSHOT_DIR"] ?? NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        Task {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: scriptPath))
                let steps = try JSONDecoder().decode([Step].self, from: data)
                try await Task.sleep(for: .seconds(1))
                for (index, step) in steps.enumerated() {
                    progress("step \(index) start", output: output)
                    try await perform(step, model: model, output: output)
                    progress("step \(index) done", output: output)
                }
            } catch {
                log("script failed: \(error)", output: output)
                try? Data("FAIL\nscript failed: \(error)\n".utf8).write(to: output.appendingPathComponent("result.txt"))
                NSApp.terminate(nil)
            }
        }
    }

    /// Within a step: actions first, then `wait`, `waitIdle`, the checks
    /// and the snapshot, then `quit`.
    private static func perform(_ step: Step, model: DocumentWindowModel, output: URL) async throws {
        let textView = model.editor.textView
        if let marker = step.caretAfter, let textView {
            let range = (textView.string as NSString).range(of: marker)
            if range.location != NSNotFound { textView.setSelectedRange(NSRange(location: NSMaxRange(range), length: 0)) }
        }
        if step.caretAtEnd == true, let textView {
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        }
        if let text = step.type, let textView {
            textView.debugSuppressCompletionPopup = true
            textView.window?.makeFirstResponder(textView)
            // One character at a time, like typing, so auto-completion triggers.
            for character in text {
                textView.insertText(String(character), replacementRange: textView.selectedRange())
                try await Task.sleep(for: .milliseconds(40))
            }
        }
        if step.complete == true { textView?.complete(nil) }
        if let review = step.review {
            // Without animation: animations don't run while the screen is locked.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { model.showReview = review }
        }
        if let id = step.run, let action = model.configuration.aiActions.first(where: { $0.id == id }) {
            model.run(action)
        }
        if step.cancel == true { model.cancelAction() }
        if let index = step.accept, model.session.highlights.indices.contains(index) {
            model.accept(model.session.highlights[index].id)
        }
        if let index = step.dismiss, model.session.highlights.indices.contains(index) {
            model.dismiss(model.session.highlights[index].id)
        }
        if step.undo == true { textView?.undoManager?.undo() }
        if let renderer = step.renderer { model.rendererID = renderer }
        if let preview = step.preview { model.showPreview = preview }

        if let seconds = step.wait { try await Task.sleep(for: .seconds(seconds)) }
        if step.waitIdle == true {
            while model.isRunningAction || model.isPreviewPending {
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        if let expectation = step.expect {
            check(expectation, model: model)
        }
        if let name = step.snapshot {
            try await Task.sleep(for: .milliseconds(300))
            await snapshot(name, model: model, output: output)
        }
        if step.quit == true {
            let result = failures.isEmpty ? "PASS\n" : "FAIL\n" + failures.joined(separator: "\n") + "\n"
            try? Data(result.utf8).write(to: output.appendingPathComponent("result.txt"))
            NSApp.terminate(nil)
        }
    }

    private static func check(_ e: Expectation, model: DocumentWindowModel) {
        let text = model.editor.currentText
        func expect(_ ok: Bool, _ message: @autoclosure () -> String) {
            if !ok { failures.append(message()) }
        }
        if let value = e.text { expect(text == value, "text is \(text.debugDescription), expected \(value.debugDescription)") }
        if let value = e.textContains { expect(text.contains(value), "text lacks \(value.debugDescription)") }
        if let value = e.textLacks { expect(!text.contains(value), "text contains \(value.debugDescription)") }
        if let value = e.isPelican { expect(model.isPelican == value, "isPelican is \(model.isPelican)") }
        if let value = e.isEditable {
            let editable = model.editor.textView?.isEditable ?? false
            expect(editable == value, "isEditable is \(editable)")
        }
        if let value = e.renderer { expect(model.rendererID == value, "renderer is \(model.rendererID)") }
        if let value = e.previewContains {
            expect(model.previewHTML?.contains(value) == true, "preview lacks \(value.debugDescription)")
        }
        if let value = e.previewError {
            expect((model.previewError != nil) == value, "previewError is \(model.previewError ?? "nil")")
        }
        if let value = e.aiError { expect((model.aiError != nil) == value, "aiError is \(model.aiError ?? "nil")") }
        if let value = e.aiNotice { expect(model.aiNotice == value, "aiNotice is \(model.aiNotice ?? "nil")") }
        if let value = e.tagCount { expect(model.tags.count == value, "tag count is \(model.tags.count)") }
        if let value = e.tagCandidatesStartWith {
            let candidates = model.editor.textView?.debugTagCandidates ?? []
            expect(Array(candidates.prefix(value.count)) == value, "tag candidates are \(candidates)")
        }
        if let value = e.autoCompletionRequested {
            let count = model.editor.textView?.debugAutoCompletionCount ?? 0
            expect((count > 0) == value, "auto completion count is \(count)")
        }
        if let value = e.statuses {
            var counts: [String: Int] = [:]
            for suggestion in model.session.suggestions { counts["\(suggestion.status)", default: 0] += 1 }
            expect(counts == value, "suggestion statuses are \(counts)")
        }
        if let value = e.selectedSuggestion {
            expect(model.selectedSuggestion?.original == value,
                   "selected suggestion is \(model.selectedSuggestion?.original ?? "nil")")
        }
        if let value = e.showReview { expect(model.showReview == value, "showReview is \(model.showReview)") }
        if let value = e.words { expect(model.statistics.words == value, "word count is \(model.statistics.words)") }
    }

    private static func snapshot(_ name: String, model: DocumentWindowModel, output: URL) async {
        var previewImage: NSImage?
        if model.showPreview, let webView = previewWebView {
            previewImage = try? await webView.takeSnapshot(configuration: nil)
            if let tiff = previewImage?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                try? rep.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent("\(name)-preview.png"))
            }
        }
        if let window = model.editor.textView?.window, let view = window.contentView?.superview ?? window.contentView,
           let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            // cacheDisplay can't capture web views; paint the preview snapshot in.
            if let previewImage, let webView = previewWebView, webView.window === window,
               let context = NSGraphicsContext(bitmapImageRep: rep) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                let frame = webView.convert(webView.bounds, to: view)
                previewImage.draw(in: view.isFlipped
                    ? NSRect(x: frame.minX, y: view.bounds.height - frame.maxY, width: frame.width, height: frame.height)
                    : frame)
                NSGraphicsContext.restoreGraphicsState()
            }
            try? rep.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent("\(name)-window.png"))
        }
        if let controller = model.editor.textView?.window?.contentViewController {
            var lines: [String] = []
            func walk(_ c: NSViewController, _ depth: Int) {
                var line = String(repeating: "  ", count: depth) + "\(type(of: c))"
                if let split = c as? NSSplitViewController {
                    line += " items: " + split.splitViewItems.map {
                        "[\($0.behavior.rawValue) collapsed=\($0.isCollapsed) min=\($0.minimumThickness)]"
                    }.joined(separator: " ")
                }
                lines.append(line)
                c.children.forEach { walk($0, depth + 1) }
            }
            walk(controller, 0)
            try? Data(lines.joined(separator: "\n").utf8).write(to: output.appendingPathComponent("\(name)-controllers.txt"))
        }
        if let frame = model.editor.textView?.window?.contentView?.superview {
            try? Data(hierarchy(frame).utf8).write(to: output.appendingPathComponent("\(name)-views.txt"))
        }
        let state: [String: Any] = [
            "text": model.editor.currentText,
            "selection": NSStringFromRange(model.editor.selectedRange),
            "isEditable": model.editor.textView?.isEditable ?? false,
            "isPelican": model.isPelican,
            "autoCompletionCount": model.editor.textView?.debugAutoCompletionCount ?? 0,
            "tagCandidates": model.editor.textView?.debugTagCandidates.map { Array($0.prefix(10)) } ?? NSNull(),
            "showReview": model.showReview,
            "windowVisible": model.editor.textView?.window?.occlusionState.contains(.visible) ?? false,
            "showPreview": model.showPreview,
            "windowFrame": NSStringFromRect(model.editor.textView?.window?.frame ?? .zero),
            "words": model.statistics.words,
            "renderer": model.rendererID,
            "previewError": model.previewError ?? NSNull(),
            "previewHTMLStart": String((model.previewHTML ?? "").prefix(400)),
            "tags": model.tags.map(\.name),
            "tagError": model.tagError ?? NSNull(),
            "aiError": model.aiError ?? NSNull(),
            "selectedSuggestion": model.selectedSuggestion?.original ?? NSNull(),
            "suggestions": model.session.suggestions.map { suggestion in
                [
                    "original": suggestion.original,
                    "replacement": suggestion.replacement ?? NSNull(),
                    "status": "\(suggestion.status)",
                    "range": suggestion.range.map(NSStringFromRange) ?? NSNull(),
                ] as [String: Any]
            },
        ]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: output.appendingPathComponent("\(name)-state.json"))
        }
    }

    private static func hierarchy(_ view: NSView, depth: Int = 0) -> String {
        guard depth < 40 else { return "" }
        var line = String(repeating: "  ", count: depth) + "\(type(of: view)) \(NSStringFromRect(view.frame))"
        if view.isHidden { line += " hidden" }
        if let identifier = view.accessibilityIdentifier() as String?, !identifier.isEmpty { line += " id=\(identifier)" }
        return ([line] + view.subviews.map { hierarchy($0, depth: depth + 1) }).joined(separator: "\n")
    }

    private static func progress(_ message: String, output: URL) {
        let url = output.appendingPathComponent("progress.txt")
        let line = Data("\(Date().timeIntervalSince1970) \(message)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }

    private static func log(_ message: String, output: URL) {
        try? Data(message.utf8).write(to: output.appendingPathComponent("harness-error.txt"))
    }
}
#endif
