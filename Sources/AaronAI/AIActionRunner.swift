import AaronCore
import Foundation

public struct AIActionRequest: Sendable {
    public var actionPrompt: String
    public var providerCommand: String
    public var timeout: Duration
    /// The exact text suggestions will be resolved against.
    public var document: String
    public var selection: String?
    public var workingDirectory: URL?

    public init(actionPrompt: String, providerCommand: String, timeout: Duration,
                document: String, selection: String?, workingDirectory: URL? = nil) {
        self.actionPrompt = actionPrompt
        self.providerCommand = providerCommand
        self.timeout = timeout
        self.document = document
        self.selection = selection
        self.workingDirectory = workingDirectory
    }
}

public enum AIActionError: Error, Equatable, LocalizedError {
    case noCommand
    /// The provider answered, but not with suggestions; carries the start of its output.
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .noCommand: "The AI provider has no command configured."
        case .invalidResponse(let output):
            "The AI's answer did not contain suggestions in the expected format.\n\n\(output)"
        }
    }
}

/// Runs an AI action: builds the prompt, pipes it to the provider command
/// and extracts the suggestions from its answer.
public struct AIActionRunner: Sendable {
    public var processRunner: ProcessRunner

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    public func run(_ request: AIActionRequest) async throws -> [RawSuggestion] {
        guard !request.providerCommand.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AIActionError.noCommand
        }
        let prompt = PromptBuilder.build(actionPrompt: request.actionPrompt,
                                         document: request.document, selection: request.selection)
        let result = try await processRunner.run(request.providerCommand, input: prompt,
                                                 workingDirectory: request.workingDirectory,
                                                 timeout: request.timeout)
        do {
            return try ResponseExtractor.suggestions(from: result.stdout)
        } catch {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            throw AIActionError.invalidResponse(output.count > 1000 ? String(output.prefix(1000)) + "…" : output)
        }
    }
}
