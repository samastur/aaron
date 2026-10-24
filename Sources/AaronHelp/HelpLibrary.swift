import Foundation

/// A plugin as reported by the plugins command.
public struct PluginName: Equatable, Sendable {
    /// As printed, e.g. `pelican.plugins.simple_footnotes`.
    public var name: String
    /// Normalised for looking up help, e.g. `simple_footnotes`.
    public var key: String
}

/// Parses the output of the plugins command: one name per line, a JSON
/// list of names, or `{"plugins": [...]}`.
public enum PluginList {
    public static func parse(_ output: String) -> [PluginName] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        var names: [String]
        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let list = (object as? [String]) ?? ((object as? [String: Any])?["plugins"] as? [String]) {
            names = list
        } else {
            names = trimmed.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        var seen = Set<String>()
        return names.filter { !$0.isEmpty }.compactMap { name in
            let key = key(for: name)
            guard seen.insert(key).inserted else { return nil }
            return PluginName(name: name, key: key)
        }
    }

    /// `pelican.plugins.simple_footnotes` → `simple_footnotes`,
    /// `pelican-sitemap` → `sitemap`, `Render-Math` → `render_math`.
    static func key(for name: String) -> String {
        var key = name.lowercased().replacingOccurrences(of: "-", with: "_")
        if let last = key.split(separator: ".").last { key = String(last) }
        if key.hasPrefix("pelican_") { key.removeFirst("pelican_".count) }
        return key
    }
}

/// What Markdown Help shows for a Pelican post.
public struct PelicanHelpContext: Equatable, Sendable {
    public var plugins: [PluginName]
    public var pluginsCommandConfigured: Bool
    public var error: String?

    public init(plugins: [PluginName], pluginsCommandConfigured: Bool, error: String? = nil) {
        self.plugins = plugins
        self.pluginsCommandConfigured = pluginsCommandConfigured
        self.error = error
    }
}

/// Assembles Markdown Help from the bundled texts and, optionally, a folder
/// of the user's own `<plugin>.md` files, which take precedence.
public struct HelpLibrary: Sendable {
    public var extraDirectory: URL?

    public init(extraDirectory: URL?) {
        self.extraDirectory = extraDirectory
    }

    private static var helpFolder: URL? {
        Bundle.module.url(forResource: "Help", withExtension: nil)
    }

    private func bundled(_ path: String) -> String? {
        guard let url = Self.helpFolder?.appendingPathComponent(path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Plugins Aaron has help for.
    public var bundledPluginKeys: [String] {
        guard let folder = Self.helpFolder?.appendingPathComponent("plugins"),
              let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return files.filter { $0.hasSuffix(".md") }.map { String($0.dropLast(3)) }.sorted()
    }

    public func pluginHelp(for key: String) -> String? {
        if let extraDirectory,
           let text = try? String(contentsOf: extraDirectory.appendingPathComponent("\(key).md"), encoding: .utf8) {
            return text
        }
        return bundled("plugins/\(key).md")
    }

    /// The help document in Markdown; the Pelican part only when `pelican`
    /// is given.
    public func markdown(pelican: PelicanHelpContext?) -> String {
        var parts = [bundled("markdown.md") ?? "# Markdown help"]
        if let pelican {
            parts.append(bundled("pelican.md") ?? "")
            parts.append(pluginsSection(pelican))
        }
        return parts.joined(separator: "\n\n")
    }

    private func pluginsSection(_ context: PelicanHelpContext) -> String {
        var section = "## Plugins\n\n"
        if let error = context.error {
            return section + "The plugins command failed:\n\n```\n\(error)\n```\n"
        }
        guard context.pluginsCommandConfigured else {
            return section + """
                To see help for the plugins this site uses, set a plugins command in \
                **Settings ▸ Pelican**. It should print the names of the plugins, \
                for example those in `PLUGINS` in `pelicanconf.py`.
                """
        }
        guard !context.plugins.isEmpty else {
            return section + "This site uses no plugins.\n"
        }
        section += "This site uses \(context.plugins.count) plugin\(context.plugins.count == 1 ? "" : "s").\n"
        for plugin in context.plugins {
            section += "\n### \(plugin.key)\n\n"
            if plugin.name != plugin.key { section += "`\(plugin.name)`\n\n" }
            section += pluginHelp(for: plugin.key) ?? """
                Aaron has no help for this plugin. You can add your own: write \
                `\(plugin.key).md` in the help folder set in **Settings ▸ Pelican**.
                """
            section += "\n"
        }
        return section
    }
}
