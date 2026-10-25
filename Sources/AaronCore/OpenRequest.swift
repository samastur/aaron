import Foundation

/// A request from the `aaron` command to open files:
/// `aaron://open?token=T&profile=P&path=/a&path=/b`. The token proves the
/// request comes from the command and not from a web page or another app.
public struct OpenRequest: Equatable, Sendable {
    public static let scheme = "aaron"

    public var token: String
    public var profile: String?
    public var paths: [String]

    public init(token: String, profile: String?, paths: [String]) {
        self.token = token
        self.profile = profile
        self.paths = paths
    }

    public init?(url: URL) {
        guard url.scheme == Self.scheme, url.host == "open",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let token = items.first { $0.name == "token" }?.value ?? ""
        let paths = items.filter { $0.name == "path" }.compactMap(\.value).filter { !$0.isEmpty }
        guard !token.isEmpty, !paths.isEmpty else { return nil }
        self.token = token
        profile = items.first { $0.name == "profile" }?.value.flatMap { $0.isEmpty ? nil : $0 }
        self.paths = paths
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = "open"
        var items = [URLQueryItem(name: "token", value: Self.encode(token))]
        if let profile { items.append(URLQueryItem(name: "profile", value: Self.encode(profile))) }
        items += paths.map { URLQueryItem(name: "path", value: Self.encode($0)) }
        components.percentEncodedQueryItems = items
        return components.url!
    }

    /// Everything but unreserved characters and `/` is encoded, as the
    /// command does, so `&`, `+`, `#` and `%` in paths survive.
    private static let allowed = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~/")

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
