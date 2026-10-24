import Foundation

/// Word and character counts of a document's body (metadata excluded).
public struct TextStatistics: Equatable, Sendable {
    public var words: Int
    public var characters: Int

    public init(words: Int, characters: Int) {
        self.words = words
        self.characters = characters
    }

    public init(text: String) {
        var body = text
        if let frontMatter = FrontMatter.parse(text) {
            body = (text as NSString).substring(from: frontMatter.bodyStart)
        }
        var words = 0
        body.enumerateSubstrings(in: body.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            words += 1
        }
        self.init(words: words, characters: body.count)
    }
}
