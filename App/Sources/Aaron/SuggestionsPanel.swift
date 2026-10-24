import AaronAI
import AaronCore
import SwiftUI

/// Review mode: run AI actions and work through their suggestions.
struct SuggestionsPanel: View {
    @Bindable var model: DocumentWindowModel
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error = model.aiError {
                ErrorNote(message: error) { model.aiError = nil }
            } else if let notice = model.aiNotice {
                Text(notice)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .accessibilityIdentifier("aiNotice")
            }
            if model.visibleSuggestions.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    List(selection: Binding(
                        get: { model.selectedSuggestionID },
                        set: { model.select($0) })) {
                        ForEach(model.visibleSuggestions) { suggestion in
                            SuggestionRow(suggestion: suggestion, model: model)
                                .tag(suggestion.id)
                                .id(suggestion.id)
                        }
                    }
                    .accessibilityIdentifier("suggestionsList")
                    .onChange(of: model.selectedSuggestionID) { _, id in
                        if let id { withAnimation { proxy.scrollTo(id) } }
                    }
                }
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Review").font(.headline)
                Spacer()
                Menu("Run") {
                    ForEach(appModel.configuration.aiActions) { action in
                        Button(action.name) { model.run(action) }
                    }
                }
                .fixedSize()
                .disabled(model.isRunningAction || appModel.configuration.aiActions.isEmpty)
                .accessibilityIdentifier("runActionMenu")
            }
            if let name = model.runningActionName {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Running “\(name)”…").font(.callout)
                    Spacer()
                    Button("Cancel") { model.cancelAction() }
                        .accessibilityIdentifier("cancelAction")
                }
                Text("Editing is paused until the AI answers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "text.badge.checkmark")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(model.session.suggestions.isEmpty ? "No suggestions yet" : "All suggestions handled")
                .font(.headline)
            Text("Choose an action from Run. Select text first to review only that passage.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(summary)
                .font(.caption)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("reviewSummary")
            Spacer()
            Toggle("Show handled", isOn: $model.showHandledSuggestions)
                .toggleStyle(.checkbox)
                .font(.caption)
            Button("Clear") { model.clearSuggestions() }
                .disabled(model.session.suggestions.isEmpty || model.isRunningAction)
                .help("Remove all suggestions")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var summary: String {
        let all = model.session.suggestions
        let open = all.filter { $0.status == .open }.count
        let accepted = all.filter { $0.status == .accepted }.count
        let dismissed = all.filter { $0.status == .dismissed }.count
        guard !all.isEmpty else { return "" }
        return "\(open) open · \(accepted + dismissed) handled"
    }
}

private struct ErrorNote: View {
    let message: String
    let close: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            ScrollView {
                Text(message)
                    .font(.callout)
                    .accessibilityIdentifier("aiErrorMessage")
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 140)
            Button(action: close) { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .accessibilityIdentifier("aiError")
    }
}

struct SuggestionRow: View {
    let suggestion: Suggestion
    let model: DocumentWindowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(suggestion.category?.capitalized ?? suggestion.actionName)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: EditorStyles.suggestionColor(suggestion)).opacity(0.2),
                                in: Capsule())
                if suggestion.category != nil {
                    Text(suggestion.actionName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }
            if !suggestion.message.isEmpty {
                Text(suggestion.message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            changeView
            if suggestion.status == .open || suggestion.status == .stale
                || suggestion.status == .notFound || suggestion.status == .ambiguous {
                HStack {
                    if suggestion.replacement != nil && suggestion.status == .open {
                        Button("Accept") { model.accept(suggestion.id) }
                            .disabled(!suggestion.canAccept || model.isRunningAction)
                            .accessibilityIdentifier("acceptSuggestion")
                    }
                    Button("Dismiss") { model.dismiss(suggestion.id) }
                        .accessibilityIdentifier("dismissSuggestion")
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .opacity(suggestion.status == .accepted || suggestion.status == .dismissed ? 0.55 : 1)
    }

    @ViewBuilder private var changeView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(styled(suggestion.original,
                        color: suggestion.replacement != nil ? .systemRed : .secondaryLabelColor,
                        strikethrough: suggestion.replacement != nil))
            if let replacement = suggestion.replacement {
                Text(styled(replacement.isEmpty ? "(remove)" : replacement, color: .systemGreen, strikethrough: false))
            }
        }
        .font(.callout.monospaced())
        .lineLimit(6)
        .textSelection(.enabled)
    }

    /// Colour set on the text itself: selectable text ignores foregroundStyle.
    private func styled(_ text: String, color: NSColor, strikethrough: Bool) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = Color(nsColor: color)
        if strikethrough { attributed.strikethroughStyle = .single }
        return attributed
    }

    @ViewBuilder private var statusBadge: some View {
        switch suggestion.status {
        case .open: EmptyView()
        case .accepted: Label("Accepted", systemImage: "checkmark").font(.caption).foregroundStyle(.green)
        case .dismissed: Label("Dismissed", systemImage: "xmark").font(.caption).foregroundStyle(.secondary)
        case .stale:
            Label("Text changed", systemImage: "pencil.slash").font(.caption).foregroundStyle(.orange)
                .help("The text this suggestion refers to was edited, so it can no longer be applied.")
        case .notFound:
            Label("Not found in text", systemImage: "questionmark.circle").font(.caption).foregroundStyle(.orange)
                .help("The AI quoted text that does not appear in the document.")
        case .ambiguous:
            Label("Ambiguous", systemImage: "questionmark.circle").font(.caption).foregroundStyle(.orange)
                .help("The quoted text appears in several places and could not be located exactly.")
        }
    }
}
