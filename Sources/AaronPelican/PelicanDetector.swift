import AaronCore

/// Decides whether a document is a Pelican post: a `Key: value` metadata
/// block at the top that includes `Title:`.
public enum PelicanDetector {
    public static func isPelican(_ text: String, detection: PelicanSettings.Detection) -> Bool {
        switch detection {
        case .always: return true
        case .never: return false
        case .automatic:
            guard let frontMatter = FrontMatter.parse(text), frontMatter.style == .pelican else { return false }
            return frontMatter.field(named: "Title") != nil
        }
    }
}
