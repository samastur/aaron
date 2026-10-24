import Foundation
import Testing
@testable import AaronCore

struct CommandTemplateTests {
    let context = CommandContext(
        fileURL: URL(fileURLWithPath: "/Users/me/blog/content/my post.md"),
        baseDirectory: URL(fileURLWithPath: "/Users/me/blog/content"),
        temporaryFileURL: URL(fileURLWithPath: "/tmp/x/my post.md"))

    @Test func expandsFilePlaceholdersWithQuoting() {
        let cmd = CommandTemplate.expand("preview {file} --name {filename}", context: context)
        #expect(cmd == "preview '/Users/me/blog/content/my post.md' --name 'my post.md'")
    }

    @Test func expandsDirectoryStemAndRelativePath() {
        let cmd = CommandTemplate.expand("x {dir} {stem} {relpath}", context: context)
        #expect(cmd == "x /Users/me/blog/content 'my post' 'my post.md'")
    }

    @Test func relativePathKeepsSubfolders() {
        let ctx = CommandContext(fileURL: URL(fileURLWithPath: "/b/content/pages/about.md"),
                                 baseDirectory: URL(fileURLWithPath: "/b/content"), temporaryFileURL: nil)
        #expect(CommandTemplate.expand("{relpath}", context: ctx) == "pages/about.md")
    }

    @Test func relativePathOutsideBaseFallsBackToFilename() {
        let ctx = CommandContext(fileURL: URL(fileURLWithPath: "/elsewhere/a.md"),
                                 baseDirectory: URL(fileURLWithPath: "/b/content"), temporaryFileURL: nil)
        #expect(CommandTemplate.expand("{relpath}", context: ctx) == "a.md")
    }

    @Test func untitledDocumentUsesDefaults() {
        let ctx = CommandContext(fileURL: nil, baseDirectory: nil, temporaryFileURL: nil)
        #expect(CommandTemplate.expand("{filename} {stem} {relpath}", context: ctx) == "untitled.md untitled untitled.md")
        #expect(CommandTemplate.expand("[{file}] [{dir}]", context: ctx) == "[''] ['']")
    }

    @Test func tmpfilePlaceholder() {
        #expect(CommandTemplate.expand("cat {tmpfile}", context: context) == "cat '/tmp/x/my post.md'")
    }

    @Test func unknownPlaceholdersAreLeftAlone() {
        #expect(CommandTemplate.expand("echo {nope} ${HOME}", context: context) == "echo {nope} ${HOME}")
    }

    @Test func substitutedValuesAreNotExpandedAgain() {
        let ctx = CommandContext(fileURL: URL(fileURLWithPath: "/b/{tmpfile}.md"), baseDirectory: nil,
                                 temporaryFileURL: URL(fileURLWithPath: "/tmp/t.md"))
        #expect(CommandTemplate.expand("{file} {tmpfile}", context: ctx) == "'/b/{tmpfile}.md' /tmp/t.md")
    }

    @Test func quotesSingleQuotes() {
        #expect(CommandTemplate.shellQuote("it's") == #"'it'\''s'"#)
        #expect(CommandTemplate.shellQuote("plain-path/x.md") == "plain-path/x.md")
    }

    @Test func detectsPlaceholderUse() {
        #expect(CommandTemplate.uses("tmpfile", in: "cat {tmpfile}"))
        #expect(!CommandTemplate.uses("tmpfile", in: "cat {file}"))
    }
}
