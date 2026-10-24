import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdownText = UTType(importedAs: "net.daringfireball.markdown")
}

/// A Markdown (or plain text) file. The text is stored as UTF-8.
struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdownText, .plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
