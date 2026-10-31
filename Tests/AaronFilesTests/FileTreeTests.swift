import Foundation
import Testing
@testable import AaronFiles

struct FileTreeTests {
    let root = URL(fileURLWithPath: "/r")

    func builder(ignored: [String] = ["node_modules"], iCloud: URL? = nil,
                 hidden: Set<String> = []) -> FileTreeBuilder {
        FileTreeBuilder(root: root, ignoredFolders: ignored, iCloudDrive: iCloud,
                        isHidden: { hidden.contains($0.path) })
    }

    func files(_ paths: [String]) -> [URL] { paths.map { URL(fileURLWithPath: "/r/" + $0) } }

    /// The tree as indented lines, folders with a trailing slash.
    func outline(_ nodes: [FileNode], depth: Int = 0) -> [String] {
        nodes.flatMap { node -> [String] in
            let indent = String(repeating: "  ", count: depth)
            switch node {
            case .file(let url): return [indent + url.lastPathComponent]
            case .folder(let folder): return [indent + folder.name + "/"] + outline(folder.children, depth: depth + 1)
            }
        }
    }

    @Test func prunesToFoldersWithFiles() {
        let tree = builder().build(files(["a/b/one.md", "two.md"]))
        #expect(outline(tree) == ["a/", "  b/", "    one.md", "two.md"])
    }

    @Test func skipsIgnoredAndHidden() {
        let tree = builder(hidden: ["/r/Library"]).build(
            files(["node_modules/x.md", "p/node_modules/y.md", ".git/x.md", "a/.secret.md", "Library/z.md", "ok.md"]))
        #expect(outline(tree) == ["ok.md"])
    }

    @Test func sortsFoldersFirstFinderStyle() {
        let tree = builder().build(files(["b.md", "a10/x.md", "a2/x.md", "A.md"]))
        #expect(outline(tree) == ["a2/", "  x.md", "a10/", "  x.md", "A.md", "b.md"])
    }

    @Test func iCloudDriveBecomesTopEntry() {
        let iCloud = URL(fileURLWithPath: "/r/Library/Mobile Documents/com~apple~CloudDocs")
        let tree = builder(iCloud: iCloud, hidden: ["/r/Library"]).build(
            files(["Library/Mobile Documents/com~apple~CloudDocs/Notes/n.md", "Library/other.md", "a.md"]))
        #expect(outline(tree) == ["iCloud Drive/", "  Notes/", "    n.md", "a.md"])
        guard case .folder(let folder) = tree.first else { Issue.record("no folder"); return }
        #expect(folder.isICloudDrive)
        #expect(folder.url == iCloud)
    }

    @Test func filesOutsideRootIgnored() {
        let tree = builder().build([URL(fileURLWithPath: "/elsewhere/a.md"), URL(fileURLWithPath: "/rx/b.md")]
                                   + files(["c.md"]))
        #expect(outline(tree) == ["c.md"])
    }

    @Test func keepsUnusualNames() {
        let tree = builder().build(files(["ščž #1.md", "100% done.md", "Čež.md", "čez.md"]))
        #expect(tree.count == 4)
    }

    @Test func buildsLargeTreeQuickly() {
        let paths = (0..<20_000).map { "f\($0 % 50)/g\($0 % 7)/note\($0).md" }
        let start = Date()
        let tree = builder().build(files(paths))
        #expect(Date().timeIntervalSince(start) < 1)
        #expect(tree.count == 50)
    }
}

struct FileFilterTests {
    let root = URL(fileURLWithPath: "/r")

    @Test func matchesNameOnlyIgnoringCaseAndDiacritics() {
        let files = ["notes/Čež.md", "cez/other.md", "x/CEZANNE.md"].map { URL(fileURLWithPath: "/r/" + $0) }
        let matches = filterFiles(files, root: root, query: "cez")
        #expect(Set(matches.map(\.name)) == ["CEZANNE.md", "Čež.md"])
    }

    @Test func matchShowsFolderRelativeToRoot() {
        let matches = filterFiles([URL(fileURLWithPath: "/r/a/b/one.md"), URL(fileURLWithPath: "/r/top.md")],
                                  root: root, query: "o")
        #expect(matches.map(\.folder) == ["a/b", ""])
    }

    @Test func emptyQueryMatchesNothing() {
        #expect(filterFiles([URL(fileURLWithPath: "/r/a.md")], root: root, query: "  ").isEmpty)
    }
}
