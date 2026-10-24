import Foundation

/// All user settings. Every key is optional when decoding so that a
/// hand-edited file only needs to contain what differs from the defaults.
public struct Configuration: Codable, Equatable, Sendable {
    public var editor = EditorSettings()
    public var previewRenderers: [PreviewRendererConfig] = []
    public var defaultRenderer = DefaultRenderers()
    public var aiProviders: [AIProviderConfig] = Configuration.defaultProviders
    public var aiActions: [AIActionConfig] = Configuration.defaultActions
    public var pelican = PelicanSettings()

    public init() {}

    public static let `default` = Configuration()

    public func provider(for action: AIActionConfig) -> AIProviderConfig? {
        aiProviders.first { $0.id == action.providerID }
    }

    public func renderer(withID id: String) -> PreviewRendererConfig? {
        previewRenderers.first { $0.id == id }
    }

    enum CodingKeys: String, CodingKey {
        case editor, previewRenderers, defaultRenderer, aiProviders, aiActions, pelican
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        editor = try c.decodeIfPresent(EditorSettings.self, forKey: .editor) ?? editor
        previewRenderers = try c.decodeIfPresent([PreviewRendererConfig].self, forKey: .previewRenderers) ?? previewRenderers
        defaultRenderer = try c.decodeIfPresent(DefaultRenderers.self, forKey: .defaultRenderer) ?? defaultRenderer
        aiProviders = try c.decodeIfPresent([AIProviderConfig].self, forKey: .aiProviders) ?? aiProviders
        aiActions = try c.decodeIfPresent([AIActionConfig].self, forKey: .aiActions) ?? aiActions
        pelican = try c.decodeIfPresent(PelicanSettings.self, forKey: .pelican) ?? pelican
    }

    public static let defaultProviders: [AIProviderConfig] = [
        AIProviderConfig(id: "claude", name: "Claude",
                         command: #"claude -p --tools "" --no-session-persistence"#),
        AIProviderConfig(id: "claude-web", name: "Claude (web)",
                         command: #"claude -p --tools "WebSearch,WebFetch" --allowedTools "WebSearch,WebFetch" --no-session-persistence"#),
        AIProviderConfig(id: "codex", name: "Codex",
                         command: "codex exec --skip-git-repo-check --ephemeral --sandbox read-only -"),
    ]

    public static let defaultActions: [AIActionConfig] = [
        AIActionConfig(id: "grammar", name: "Grammar and spelling", prompt: """
            Find spelling mistakes, grammatical errors, wrong punctuation and \
            typos. Keep the author's voice and do not suggest stylistic \
            rewrites. Ignore Markdown syntax, code, URLs and the metadata \
            header unless they contain a typo in prose.
            """, providerID: "claude"),
        AIActionConfig(id: "fact-check", name: "Fact check", prompt: """
            Check factual claims (names, dates, numbers, technical \
            statements, quotes) for accuracy. Report only claims that are \
            wrong, outdated or doubtful, explain why in the message and give a \
            corrected wording as the replacement when you are confident.
            """, providerID: "claude-web"),
        AIActionConfig(id: "style", name: "Style", prompt: """
            Suggest improvements to clarity, flow and concision: awkward or \
            overly long sentences, repetition, filler words, unclear \
            references. Preserve the author's voice and meaning. Prefer few, \
            valuable suggestions over many small ones.
            """, providerID: "claude"),
    ]
}

public struct EditorSettings: Codable, Equatable, Sendable {
    public var fontSize: Double = 15
    public var monospaced = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? fontSize
        monospaced = try c.decodeIfPresent(Bool.self, forKey: .monospaced) ?? monospaced
    }

    enum CodingKeys: String, CodingKey { case fontSize, monospaced }
}

/// Maps URLs requested by a preview page (`/articles/theme/x.css`) to a
/// local directory.
public struct AssetMapping: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var urlPrefix: String
    public var directory: String

    public init(id: String = UUID().uuidString, urlPrefix: String, directory: String) {
        self.id = id
        self.urlPrefix = urlPrefix
        self.directory = directory
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        urlPrefix = try c.decodeIfPresent(String.self, forKey: .urlPrefix) ?? "/"
        directory = try c.decodeIfPresent(String.self, forKey: .directory) ?? ""
    }

    enum CodingKeys: String, CodingKey { case id, urlPrefix, directory }
}

public struct PreviewRendererConfig: Codable, Equatable, Sendable, Identifiable {
    /// Identifier of the built-in Markdown renderer, which is not stored in
    /// `previewRenderers`.
    public static let builtinID = "builtin"

    public var id: String
    public var name: String
    /// Shell command; receives the document on stdin, prints HTML.
    public var command: String
    public var workingDirectory: String?
    /// Directory that `{relpath}` is relative to.
    public var baseDirectory: String?
    public var timeoutSeconds: Double
    public var assetMappings: [AssetMapping]

    public init(id: String = UUID().uuidString, name: String, command: String,
                workingDirectory: String? = nil, baseDirectory: String? = nil,
                timeoutSeconds: Double = 30, assetMappings: [AssetMapping] = []) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.baseDirectory = baseDirectory
        self.timeoutSeconds = timeoutSeconds
        self.assetMappings = assetMappings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Renderer"
        command = try c.decodeIfPresent(String.self, forKey: .command) ?? ""
        workingDirectory = try c.decodeIfPresent(String.self, forKey: .workingDirectory)
        baseDirectory = try c.decodeIfPresent(String.self, forKey: .baseDirectory)
        timeoutSeconds = try c.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? 30
        assetMappings = try c.decodeIfPresent([AssetMapping].self, forKey: .assetMappings) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, name, command, workingDirectory, baseDirectory, timeoutSeconds, assetMappings
    }
}

/// Renderer used when a window opens, by document kind.
public struct DefaultRenderers: Codable, Equatable, Sendable {
    public var markdown = PreviewRendererConfig.builtinID
    public var pelican = PreviewRendererConfig.builtinID

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        markdown = try c.decodeIfPresent(String.self, forKey: .markdown) ?? markdown
        pelican = try c.decodeIfPresent(String.self, forKey: .pelican) ?? pelican
    }

    enum CodingKeys: String, CodingKey { case markdown, pelican }
}

public struct AIProviderConfig: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// Shell command; receives the prompt on stdin, prints the answer.
    public var command: String
    public var timeoutSeconds: Double

    public init(id: String = UUID().uuidString, name: String, command: String, timeoutSeconds: Double = 300) {
        self.id = id
        self.name = name
        self.command = command
        self.timeoutSeconds = timeoutSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Provider"
        command = try c.decodeIfPresent(String.self, forKey: .command) ?? ""
        timeoutSeconds = try c.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? 300
    }

    enum CodingKeys: String, CodingKey { case id, name, command, timeoutSeconds }
}

public struct AIActionConfig: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var prompt: String
    public var providerID: String

    public init(id: String = UUID().uuidString, name: String, prompt: String, providerID: String) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.providerID = providerID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Action"
        prompt = try c.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        providerID = try c.decodeIfPresent(String.self, forKey: .providerID) ?? "claude"
    }

    enum CodingKeys: String, CodingKey { case id, name, prompt, providerID }
}

public struct PelicanSettings: Codable, Equatable, Sendable {
    public enum Detection: String, Codable, Sendable, CaseIterable {
        case automatic, always, never
    }

    public var detection = Detection.automatic
    /// Shell command printing the known tags (JSON or one per line).
    public var tagsCommand = ""
    public var tagsWorkingDirectory: String?
    public var tagsTimeoutSeconds: Double = 15

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        detection = try c.decodeIfPresent(Detection.self, forKey: .detection) ?? detection
        tagsCommand = try c.decodeIfPresent(String.self, forKey: .tagsCommand) ?? tagsCommand
        tagsWorkingDirectory = try c.decodeIfPresent(String.self, forKey: .tagsWorkingDirectory)
        tagsTimeoutSeconds = try c.decodeIfPresent(Double.self, forKey: .tagsTimeoutSeconds) ?? tagsTimeoutSeconds
    }

    enum CodingKeys: String, CodingKey { case detection, tagsCommand, tagsWorkingDirectory, tagsTimeoutSeconds }
}

/// `~` expansion for paths typed into settings.
public enum PathExpansion {
    public static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    /// A file URL for a configured path, or nil when it is blank.
    public static func url(_ path: String?) -> URL? {
        guard let path, !path.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return URL(fileURLWithPath: expand(path.trimmingCharacters(in: .whitespaces)))
    }
}

public enum ConfigurationStore {
    public static let environmentKey = "AARON_CONFIG_PATH"

    public static func defaultURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment[environmentKey], !override.isEmpty {
            return URL(fileURLWithPath: PathExpansion.expand(override))
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Aaron/config.json")
    }

    /// Loads the configuration; a missing file gives the defaults.
    public static func load(from url: URL) throws -> Configuration {
        guard FileManager.default.fileExists(atPath: url.path) else { return .default }
        return try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: url))
    }

    public static func save(_ configuration: Configuration, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(configuration).write(to: url, options: .atomic)
    }
}
