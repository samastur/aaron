/// Builds the text sent to an AI provider for an action.
public enum PromptBuilder {
    public static let responseFormat = #"""
    Respond with JSON only, no other text, in exactly this shape:

    {"suggestions": [
      {
        "original": "exact text from the document that the suggestion is about",
        "prefix": "the text immediately before original",
        "suffix": "the text immediately after original",
        "replacement": "the text that should replace original, or null",
        "message": "a short explanation for the author",
        "category": "a one or two word label, e.g. grammar, spelling, style, fact"
      }
    ]}

    Rules:
    - "original" must be copied character for character from the document,
      including Markdown syntax, punctuation and line breaks. Quote the
      shortest passage that covers the problem; never paraphrase.
    - "prefix" and "suffix" are copied from the document too: up to about 30
      characters directly before and after "original", enough to make the
      passage unique. Use "" at the start or end of the document.
    - "replacement" replaces exactly the "original" text. Use null when you
      only want to comment and have no concrete replacement.
    - Do not count characters or report positions.
    - Suggestions may overlap; report each separately.
    - If you have nothing to suggest, respond with {"suggestions": []}.
    """#

    public static func build(actionPrompt: String, document: String, selection: String?) -> String {
        var parts = [
            "You are reviewing a Markdown document for its author. Your task:",
            actionPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            responseFormat,
        ]
        if let selection, !selection.isEmpty {
            parts.append("""
            The author selected the passage below. Make suggestions only about \
            this passage; the rest of the document is context.
            <selection>
            \(selection)
            </selection>
            """)
        }
        parts.append("<document>\n\(document)\n</document>")
        return parts.joined(separator: "\n\n")
    }
}
