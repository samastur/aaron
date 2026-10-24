import Foundation

/// Fills in the new-post template: `{date}` (`2026-03-04 09:05`, Pelican's
/// usual format) and `{day}` (`2026-03-04`).
public enum PostTemplate {
    public static func expand(_ template: String, date: Date = Date()) -> String {
        template
            .replacingOccurrences(of: "{date}", with: format(date, "yyyy-MM-dd HH:mm"))
            .replacingOccurrences(of: "{day}", with: format(date, "yyyy-MM-dd"))
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
