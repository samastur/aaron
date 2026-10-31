import Foundation
import Testing
@testable import AaronFiles

struct FolderReaderTests {
    @Test func listsFoldersAndMarkdownOnly() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("reader-\(UUID().uuidString)")
        let manager = FileManager.default
        for dir in ["notes", ".hidden", "node_modules", "Tool.app", "b10", "b2"] {
            try manager.createDirectory(at: folder.appendingPathComponent(dir), withIntermediateDirectories: true)
        }
        for file in ["a.md", "B.MARKDOWN", "notes.txt", ".x.md"] {
            try Data().write(to: folder.appendingPathComponent(file))
        }
        defer { try? manager.removeItem(at: folder) }

        let nodes = FolderReader().contents(of: folder, extensions: ["md", "markdown"], ignoredFolders: ["node_modules"])
        #expect(nodes.map(\.name) == ["b2", "b10", "notes", "a.md", "B.MARKDOWN"])
        #expect(nodes.prefix(3).allSatisfy { $0.children != nil })
    }

    @Test func missingFolderGivesNothing() {
        let nodes = FolderReader().contents(of: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"),
                                            extensions: ["md"], ignoredFolders: [])
        #expect(nodes.isEmpty)
    }
}
