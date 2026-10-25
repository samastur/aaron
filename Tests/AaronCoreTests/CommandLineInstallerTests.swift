import Foundation
import Testing
@testable import AaronCore

struct CommandLineInstallerTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("aaron-install-\(UUID().uuidString)")
    var bin: URL { directory.appendingPathComponent("home/.local/bin") }

    func makeScript(_ name: String = "aaron") throws -> URL {
        let url = directory.appendingPathComponent("App\(UUID().uuidString)/\(name)")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/zsh\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func destination(of link: URL) throws -> String {
        try FileManager.default.destinationOfSymbolicLink(atPath: link.path)
    }

    @Test func createsDirectoryAndSymlink() throws {
        let script = try makeScript()
        let link = try CommandLineInstaller.install(script: script, into: bin)
        #expect(link == bin.appendingPathComponent("aaron"))
        #expect(try destination(of: link) == script.path)
    }

    @Test func replacesExistingSymlink() throws {
        let old = try makeScript(), new = try makeScript()
        _ = try CommandLineInstaller.install(script: old, into: bin)
        let link = try CommandLineInstaller.install(script: new, into: bin)
        #expect(try destination(of: link) == new.path)
    }

    @Test func refusesRegularFile() throws {
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let existing = bin.appendingPathComponent("aaron")
        try "mine".write(to: existing, atomically: true, encoding: .utf8)
        #expect(throws: InstallError.existingFile(existing)) {
            try CommandLineInstaller.install(script: try makeScript(), into: bin)
        }
        #expect(try String(contentsOf: existing, encoding: .utf8) == "mine")
    }

    @Test func pathCheckHandlesTildeAndTrailingSlash() {
        let dir = URL(fileURLWithPath: "/Users/x/.local/bin")
        #expect(CommandLineInstaller.directory(dir, isIn: "/usr/bin:/Users/x/.local/bin/"))
        #expect(!CommandLineInstaller.directory(dir, isIn: "/usr/bin:/Users/x/bin"))
        let home = URL(fileURLWithPath: NSHomeDirectory() + "/.local/bin")
        #expect(CommandLineInstaller.directory(home, isIn: "/bin:~/.local/bin"))
    }
}
