import Foundation
import Testing
import AaronCore
@testable import AaronPreview

struct PreviewAssetResolverTests {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("aaron-assets-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("output/theme"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("content/images"), withIntermediateDirectories: true)
        try Data("css".utf8).write(to: root.appendingPathComponent("output/theme/site.css"))
        try Data("png".utf8).write(to: root.appendingPathComponent("content/images/a b.png"))
    }

    var resolver: PreviewAssetResolver {
        PreviewAssetResolver(
            mappings: [AssetMapping(urlPrefix: "/articles/", directory: root.appendingPathComponent("output").path)],
            documentDirectory: root.appendingPathComponent("content"))
    }

    @Test func mapsPrefixToDirectory() {
        #expect(resolver.fileURL(forPath: "/articles/theme/site.css")?.lastPathComponent == "site.css")
    }

    @Test func fallsBackToDocumentDirectory() {
        #expect(resolver.fileURL(forPath: "/images/a%20b.png")?.lastPathComponent == "a b.png")
    }

    @Test func missingFileGivesNil() {
        #expect(resolver.fileURL(forPath: "/articles/theme/none.css") == nil)
    }

    @Test func rejectsPathTraversal() {
        #expect(resolver.fileURL(forPath: "/articles/../content/images/a%20b.png") == nil)
        #expect(resolver.fileURL(forPath: "/../../etc/passwd") == nil)
    }

    @Test func prefixWithoutSlashesStillMatches() {
        let r = PreviewAssetResolver(
            mappings: [AssetMapping(urlPrefix: "articles", directory: root.appendingPathComponent("output").path)],
            documentDirectory: nil)
        #expect(r.fileURL(forPath: "/articles/theme/site.css") != nil)
    }

    @Test func blankMappingDirectoryIsIgnored() throws {
        // A blank folder must not mean "the current directory".
        let name = "aaron-cwd-probe-\(UUID().uuidString)"
        let probe = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(name)
        try Data("x".utf8).write(to: probe)
        defer { try? FileManager.default.removeItem(at: probe) }
        for blank in ["", "  "] {
            let r = PreviewAssetResolver(mappings: [AssetMapping(urlPrefix: "/", directory: blank)], documentDirectory: nil)
            #expect(r.fileURL(forPath: "/\(name)") == nil)
        }
    }

    @Test func rejectsSymlinkLeadingOutOfFolder() throws {
        // content/link → .. would otherwise reach output/ through the
        // document folder.
        try FileManager.default.createSymbolicLink(
            atPath: root.appendingPathComponent("content/link").path, withDestinationPath: "..")
        #expect(resolver.fileURL(forPath: "/link/output/theme/site.css") == nil)
        let mapped = root.appendingPathComponent("output/theme/escape")
        try FileManager.default.createSymbolicLink(
            atPath: mapped.path, withDestinationPath: root.appendingPathComponent("content").path)
        #expect(resolver.fileURL(forPath: "/articles/theme/escape/images/a%20b.png") == nil)
    }

    @Test func followsSymlinkInsideFolder() throws {
        try FileManager.default.createSymbolicLink(
            atPath: root.appendingPathComponent("content/pictures").path, withDestinationPath: "images")
        #expect(resolver.fileURL(forPath: "/pictures/a%20b.png")?.lastPathComponent == "a b.png")
    }

    @Test func decodesRequestURLOnce() throws {
        try Data("literal".utf8).write(to: root.appendingPathComponent("content/a%20b.png"))
        let literal = try #require(URL(string: "aaron-preview://preview/a%2520b.png"))
        #expect(resolver.fileURL(for: literal).map { try? String(contentsOf: $0, encoding: .utf8) } == "literal")
        let spaced = try #require(URL(string: "aaron-preview://preview/images/a%20b.png"))
        #expect(resolver.fileURL(for: spaced)?.lastPathComponent == "a b.png")
    }

    @Test func mimeTypes() {
        #expect(PreviewAssetResolver.mimeType(for: URL(fileURLWithPath: "/a.css")) == "text/css")
        #expect(PreviewAssetResolver.mimeType(for: URL(fileURLWithPath: "/a.png")) == "image/png")
        #expect(PreviewAssetResolver.mimeType(for: URL(fileURLWithPath: "/a.unknownext")) == "application/octet-stream")
    }
}
