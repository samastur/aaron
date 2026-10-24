import Foundation
import Testing
import AaronCore
@testable import AaronPreview

struct ExternalCommandRendererTests {
    let runner = ProcessRunner(loginShell: false)

    func renderer(_ command: String, workingDirectory: String? = nil, baseDirectory: String? = nil) -> ExternalCommandRenderer {
        ExternalCommandRenderer(config: PreviewRendererConfig(
            name: "Test", command: command, workingDirectory: workingDirectory,
            baseDirectory: baseDirectory, timeoutSeconds: 10), runner: runner)
    }

    @Test func pipesBufferAndReturnsStdout() async throws {
        let html = try await renderer("sed 's/^/<p>/'").render(PreviewRequest(text: "hello", fileURL: nil))
        #expect(html == "<p>hello")
    }

    @Test func expandsPlaceholders() async throws {
        let file = URL(fileURLWithPath: "/blog/content/sub/post.md")
        let html = try await renderer("cat >/dev/null; echo {relpath} {filename}", baseDirectory: "/blog/content")
            .render(PreviewRequest(text: "x", fileURL: file))
        #expect(html == "sub/post.md post.md\n")
    }

    @Test func tmpfileContainsBufferWithOriginalName() async throws {
        let file = URL(fileURLWithPath: "/nowhere/post.md")
        let html = try await renderer("basename {tmpfile}; cat {tmpfile}")
            .render(PreviewRequest(text: "unsaved text", fileURL: file))
        #expect(html == "post.md\nunsaved text")
    }

    @Test func runsInConfiguredWorkingDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        let html = try await renderer("pwd -P", workingDirectory: dir.path).render(PreviewRequest(text: "", fileURL: nil))
        #expect(URL(fileURLWithPath: html.trimmingCharacters(in: .newlines)).resolvingSymlinksInPath() == dir)
    }

    @Test func emptyOutputIsAnError() async throws {
        await #expect(throws: PreviewError.emptyOutput) {
            try await renderer("cat >/dev/null").render(PreviewRequest(text: "x", fileURL: nil))
        }
    }

    @Test func commandFailureIsPropagated() async throws {
        await #expect(throws: ProcessError.failed(exitCode: 2, stderr: "bad post")) {
            try await renderer("echo 'bad post' >&2; exit 2").render(PreviewRequest(text: "x", fileURL: nil))
        }
    }
}
