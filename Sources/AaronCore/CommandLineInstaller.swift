import Foundation

public enum InstallError: LocalizedError, Equatable {
    case existingFile(URL)

    public var errorDescription: String? {
        switch self {
        case .existingFile(let url):
            "\(url.path) already exists and was not installed by Aaron, so it was left alone. "
                + "Remove or rename it, then install again."
        }
    }
}

/// Puts the `aaron` command on the user's PATH as a symlink to the script
/// inside the app, so it always opens files in that app.
public enum CommandLineInstaller {
    /// Where the command goes: never a Homebrew prefix or a folder that
    /// needs admin rights.
    public static var userBinDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/bin")
    }

    /// Creates `binDirectory/aaron` → `script`, replacing an older symlink.
    @discardableResult
    public static func install(script: URL, into binDirectory: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: binDirectory, withIntermediateDirectories: true)
        let link = binDirectory.appendingPathComponent("aaron")
        if (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil {
            try fm.removeItem(at: link)
        } else if fm.fileExists(atPath: link.path) {
            throw InstallError.existingFile(link)
        }
        try fm.createSymbolicLink(at: link, withDestinationURL: script)
        return link
    }

    /// Whether `directory` is one of the entries of a PATH value.
    public static func directory(_ directory: URL, isIn pathVariable: String) -> Bool {
        let target = directory.standardizedFileURL.path
        return pathVariable.split(separator: ":").contains { entry in
            URL(fileURLWithPath: PathExpansion.expand(String(entry))).standardizedFileURL.path == target
        }
    }
}
