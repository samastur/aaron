import AaronCore
import Foundation

/// Renders with a user-configured command: the buffer goes to stdin, HTML
/// comes from stdout. Placeholders describe where the document lives.
public struct ExternalCommandRenderer: PreviewRenderer {
    public var config: PreviewRendererConfig
    public var runner: ProcessRunner

    public init(config: PreviewRendererConfig, runner: ProcessRunner = ProcessRunner()) {
        self.config = config
        self.runner = runner
    }

    public func render(_ request: PreviewRequest) async throws -> String {
        var temporaryDirectory: URL?
        var temporaryFile: URL?
        if CommandTemplate.uses("tmpfile", in: config.command) {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("aaron-preview-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent(request.fileURL?.lastPathComponent ?? CommandTemplate.untitledName)
            try Data(request.text.utf8).write(to: file)
            temporaryDirectory = dir
            temporaryFile = file
        }
        defer {
            if let temporaryDirectory { try? FileManager.default.removeItem(at: temporaryDirectory) }
        }

        let context = CommandContext(fileURL: request.fileURL,
                                     baseDirectory: PathExpansion.url(config.baseDirectory),
                                     temporaryFileURL: temporaryFile)
        let command = CommandTemplate.expand(config.command, context: context)
        var workingDirectory = PathExpansion.url(config.workingDirectory)
        if workingDirectory == nil, let directory = request.fileURL?.deletingLastPathComponent(),
           FileManager.default.fileExists(atPath: directory.path) {
            workingDirectory = directory
        }
        let result = try await runner.run(command, input: request.text, workingDirectory: workingDirectory,
                                          timeout: .seconds(config.timeoutSeconds))
        guard !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PreviewError.emptyOutput
        }
        return result.stdout
    }
}

