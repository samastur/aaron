import Foundation
import Testing
import AaronCore
@testable import AaronPelican

struct TagProviderTests {
    func counterFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("aaron-tags-\(UUID().uuidString)")
    }

    @Test func runsCommandAndParsesTags() async throws {
        let provider = TagProvider(runner: ProcessRunner(loginShell: false))
        let tags = try await provider.tags(command: "printf '3 swift\\n1 ios\\n'", workingDirectory: nil, timeout: .seconds(10))
        #expect(tags == [TagInfo(name: "swift", count: 3), TagInfo(name: "ios", count: 1)])
    }

    @Test func cachesResultsUntilRefresh() async throws {
        let file = counterFile()
        let provider = TagProvider(runner: ProcessRunner(loginShell: false))
        let command = "echo x >> \(file.path); echo tag"
        _ = try await provider.tags(command: command, workingDirectory: nil, timeout: .seconds(10))
        _ = try await provider.tags(command: command, workingDirectory: nil, timeout: .seconds(10))
        #expect(try String(contentsOf: file, encoding: .utf8).count == 2)
        _ = try await provider.tags(command: command, workingDirectory: nil, timeout: .seconds(10), refresh: true)
        #expect(try String(contentsOf: file, encoding: .utf8).count == 4)
    }

    @Test func emptyCommandGivesNoTags() async throws {
        let provider = TagProvider(runner: ProcessRunner(loginShell: false))
        #expect(try await provider.tags(command: "  ", workingDirectory: nil, timeout: .seconds(10)).isEmpty)
    }
}
