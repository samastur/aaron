import Foundation

public struct PreviewRequest: Sendable, Equatable {
    /// The current, possibly unsaved, buffer.
    public var text: String
    public var fileURL: URL?

    public init(text: String, fileURL: URL?) {
        self.text = text
        self.fileURL = fileURL
    }
}

public enum PreviewError: Error, Equatable, LocalizedError {
    case emptyOutput

    public var errorDescription: String? {
        switch self {
        case .emptyOutput: "The preview command finished without printing any HTML."
        }
    }
}

/// Produces an HTML page for the preview panel.
public protocol PreviewRenderer: Sendable {
    func render(_ request: PreviewRequest) async throws -> String
}

enum HTML {
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
