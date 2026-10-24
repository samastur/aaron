import AaronCore
import Foundation
import UniformTypeIdentifiers

/// Maps paths requested by the preview page to local files: configured URL
/// prefixes first, then the document's directory. Paths escaping the target
/// directory are rejected.
public struct PreviewAssetResolver: Sendable {
    public var mappings: [AssetMapping]
    public var documentDirectory: URL?

    public init(mappings: [AssetMapping], documentDirectory: URL?) {
        self.mappings = mappings
        self.documentDirectory = documentDirectory
    }

    /// `path` is the URL's (percent-encoded) path, e.g. `/articles/theme/x.css`.
    public func fileURL(forPath path: String) -> URL? {
        let decoded = path.removingPercentEncoding ?? path
        let components = decoded.split(separator: "/").map(String.init)
        guard !components.contains("..") else { return nil }
        let normalized = "/" + components.joined(separator: "/")

        for mapping in mappings {
            let trimmed = mapping.urlPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let prefix = trimmed.isEmpty ? "/" : "/" + trimmed + "/"
            guard normalized.hasPrefix(prefix) || normalized + "/" == prefix else { continue }
            let relative = String(normalized.dropFirst(prefix.count))
            let base = URL(fileURLWithPath: PathExpansion.expand(mapping.directory))
            if let found = existing(base, relative) { return found }
        }
        if let documentDirectory {
            return existing(documentDirectory, String(normalized.dropFirst()))
        }
        return nil
    }

    private func existing(_ base: URL, _ relative: String) -> URL? {
        let candidate = relative.isEmpty ? base : base.appendingPathComponent(relative)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return nil }
        return candidate
    }

    public static func mimeType(for url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}
