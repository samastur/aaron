import Foundation
import Testing
@testable import AaronCore

/// Runs `App/Sources/Aaron/Resources/aaron` in dry-run mode, which prints
/// the URL it would send instead of calling `open`.
struct CommandScriptTests {
    static let script = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("App/Sources/Aaron/Resources/aaron")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("aaron-cli-\(UUID().uuidString)")
    var support: URL { directory.appendingPathComponent("support") }
    var store: ProfileStore { ProfileStore(directory: support) }

    init() throws {
        let store = ProfileStore(directory: directory.appendingPathComponent("support"))
        try store.save(.default, as: "Default")
        try store.save(.default, as: "Blog")
        try store.setDefaultProfile("Blog")
        _ = try store.cliToken()
    }

    struct Result { var status: Int32; var stdout: String; var stderr: String }

    func run(_ arguments: [String]) throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [Self.script.path] + arguments
        process.currentDirectoryURL = directory
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["AARON_SUPPORT_DIR": support.path, "AARON_CLI_DRY_RUN": "1"]) { _, new in new }
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let stdout = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return Result(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    func touch(_ name: String) throws {
        try "x".write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    @Test func listsProfilesMarkingDefault() throws {
        let result = try run(["--list-profiles"])
        #expect(result.status == 0)
        #expect(result.stdout == "Blog (default)\nDefault\n")
    }

    @Test func helpAndUsage() throws {
        let help = try run(["--help"])
        #expect(help.status == 0)
        #expect(help.stdout.contains("--profile"))
        let none = try run([])
        #expect(none.status == 2)
        #expect(none.stderr.contains("usage"))
    }

    @Test func missingFileFailsAndOpensNothing() throws {
        try touch("here.md")
        let result = try run(["here.md", "missing.md"])
        #expect(result.status == 1)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("no such file: missing.md"))
    }

    @Test func unknownProfileListsAvailable() throws {
        try touch("here.md")
        let result = try run(["--profile", "Nope", "here.md"])
        #expect(result.status == 1)
        #expect(result.stderr.contains(#"unknown profile "Nope""#))
        #expect(result.stderr.contains("Blog, Default"))
    }

    @Test func printsDecodableURL() throws {
        let awkward = "a b&c#%ü+.md"
        try touch(awkward)
        try touch("plain.md")
        let result = try run(["--profile", "blog", awkward, "./plain.md"])
        #expect(result.status == 0, "\(result.stderr)")
        let url = try #require(URL(string: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)))
        let request = try #require(OpenRequest(url: url))
        #expect(request.token == (try store.cliToken()))
        #expect(request.profile == "Blog")
        let real = directory.resolvingSymlinksInPath().path
        #expect(request.paths.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
                == [real + "/" + awkward, real + "/plain.md"])
    }

    @Test func withoutProfileSendsNone() throws {
        try touch("plain.md")
        let result = try run(["plain.md"])
        let url = try #require(URL(string: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)))
        let request = try #require(OpenRequest(url: url))
        #expect(request.profile == nil)
    }
}
