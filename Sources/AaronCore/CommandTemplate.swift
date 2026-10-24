import Foundation

/// Where the document lives, for expanding command placeholders.
public struct CommandContext: Sendable, Equatable {
    public var fileURL: URL?
    /// Directory `{relpath}` is relative to.
    public var baseDirectory: URL?
    /// A temporary copy of the current buffer, if one was written.
    public var temporaryFileURL: URL?

    public init(fileURL: URL?, baseDirectory: URL?, temporaryFileURL: URL?) {
        self.fileURL = fileURL
        self.baseDirectory = baseDirectory
        self.temporaryFileURL = temporaryFileURL
    }
}

/// Expands `{placeholder}`s in user-configured shell commands. Every
/// substituted value is shell-quoted, so paths with spaces are safe.
public enum CommandTemplate {
    public static let placeholders = ["file", "dir", "filename", "stem", "relpath", "tmpfile"]
    public static let untitledName = "untitled.md"

    private static let placeholderPattern = try! NSRegularExpression(
        pattern: "\\{(" + placeholders.joined(separator: "|") + ")\\}")

    /// Replaces placeholders in one pass, so substituted values are never
    /// expanded again.
    public static func expand(_ template: String, context: CommandContext) -> String {
        let ns = template as NSString
        var result = ""
        var last = 0
        for match in placeholderPattern.matches(in: template, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            result += shellQuote(value(of: ns.substring(with: match.range(at: 1)), context: context))
            last = NSMaxRange(match.range)
        }
        return result + ns.substring(from: last)
    }

    public static func uses(_ placeholder: String, in template: String) -> Bool {
        template.contains("{\(placeholder)}")
    }

    static func value(of name: String, context: CommandContext) -> String {
        let file = context.fileURL?.standardizedFileURL
        switch name {
        case "file": return file?.path ?? ""
        case "dir": return file?.deletingLastPathComponent().path ?? ""
        case "filename": return file?.lastPathComponent ?? untitledName
        case "stem": return file?.deletingPathExtension().lastPathComponent
            ?? (untitledName as NSString).deletingPathExtension
        case "relpath": return relativePath(file, base: context.baseDirectory)
        case "tmpfile": return context.temporaryFileURL?.path ?? ""
        default: return ""
        }
    }

    static func relativePath(_ file: URL?, base: URL?) -> String {
        guard let file else { return untitledName }
        if let base {
            let basePath = base.standardizedFileURL.path
            let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
            if file.path.hasPrefix(prefix) {
                return String(file.path.dropFirst(prefix.count))
            }
        }
        return file.lastPathComponent
    }

    /// POSIX shell quoting; plain words are left unquoted for readability.
    public static func shellQuote(_ value: String) -> String {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./:=@%+,")
        if !value.isEmpty, value.unicodeScalars.allSatisfy({ safe.contains($0) }) {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}
