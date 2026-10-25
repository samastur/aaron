import Foundation
import Testing
@testable import AaronCore

struct ProfileStoreTests {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("aaron-profiles-\(UUID().uuidString)")
    var store: ProfileStore { ProfileStore(directory: directory) }

    func write(_ text: String, to name: String) throws {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
    }

    @Test func migratesConfigJSONIntoDefault() throws {
        try write(#"{"editor":{"fontSize":20}}"#, to: "config.json")
        try store.prepare()
        #expect(store.names() == ["Default"])
        #expect(try store.load("Default").editor.fontSize == 20)
        #expect(!exists("config.json"))
        #expect(exists("config.json.migrated"))
    }

    @Test func freshFolderGetsBuiltinDefault() throws {
        try store.prepare()
        #expect(store.names() == ["Default"])
        #expect(try store.load("Default") == .default)
    }

    @Test func prepareDoesNotMigrateTwice() throws {
        try store.prepare()
        try write(#"{"editor":{"fontSize":25}}"#, to: "config.json")
        try store.prepare()
        #expect(try store.load("Default") == .default)
        #expect(exists("config.json"))
    }

    @Test func emptyProfilesFolderGetsDefault() throws {
        try FileManager.default.createDirectory(at: store.profilesDirectory, withIntermediateDirectories: true)
        try store.prepare()
        #expect(store.names() == ["Default"])
    }

    @Test func defaultFallsBackToFirstName() throws {
        try write("{}", to: "Profiles/Plain.json")
        try write("{}", to: "Profiles/Blog.json")
        #expect(store.names() == ["Blog", "Plain"])
        #expect(store.defaultProfileName() == "Blog")
        try write(#"{"defaultProfile":"Gone"}"#, to: "profiles.json")
        #expect(store.defaultProfileName() == "Blog")
        try store.setDefaultProfile("Plain")
        #expect(store.defaultProfileName() == "Plain")
    }

    @Test func renameKeepsDefault() throws {
        try write("{}", to: "Profiles/Blog.json")
        try write("{}", to: "Profiles/Plain.json")
        try store.setDefaultProfile("Blog")
        try store.rename("Blog", to: "Site")
        #expect(store.defaultProfileName() == "Site")
        #expect(!exists("Profiles/Blog.json"))
        #expect(store.names() == ["Plain", "Site"])
    }

    @Test func renameRejectsInvalidNames() throws {
        try write("{}", to: "Profiles/Blog.json")
        try write("{}", to: "Profiles/Plain.json")
        #expect(throws: ProfileError.self) { try store.rename("Blog", to: "plain") }
        #expect(throws: ProfileError.self) { try store.rename("Blog", to: "a/b") }
        #expect(store.names() == ["Blog", "Plain"])
        try store.rename("Blog", to: "blog")  // changing case only is allowed
        #expect(store.names() == ["blog", "Plain"])
    }

    @Test func deleteRefusesDefaultAndLast() throws {
        try write("{}", to: "Profiles/Blog.json")
        try write("{}", to: "Profiles/Plain.json")
        try store.setDefaultProfile("Blog")
        #expect(throws: ProfileError.cannotDeleteDefault) { try store.delete("Blog") }
        try store.delete("Plain")
        #expect(store.names() == ["Blog"])
        try store.setDefaultProfile("Blog")
        #expect(throws: ProfileError.self) { try store.delete("Blog") }
    }

    @Test func nameValidation() {
        for bad in ["", "  ", "a/b", "a:b", ".hidden"] {
            #expect(ProfileStore.validationError(for: bad, existing: []) != nil, "\(bad)")
        }
        #expect(ProfileStore.validationError(for: "plain", existing: ["Plain"]) != nil)
        #expect(ProfileStore.validationError(for: "Plain", existing: ["Plain"], ignoring: "Plain") == nil)
        #expect(ProfileStore.validationError(for: "Blog 2", existing: ["Plain"]) == nil)
    }

    @Test func unreadableProfileDoesNotBreakOthers() throws {
        try write("{ broken", to: "Profiles/Bad.json")
        try write(#"{"editor":{"fontSize":12}}"#, to: "Profiles/Good.json")
        #expect(store.names() == ["Bad", "Good"])
        #expect(throws: (any Error).self) { try store.load("Bad") }
        #expect(try store.load("Good").editor.fontSize == 12)
    }

    @Test func importIsLenient() throws {
        try write(#"{"pelican":{"tagsCommand":"x"}}"#, to: "import.json")
        try store.importProfile(from: directory.appendingPathComponent("import.json"), as: "Blog")
        let imported = try store.load("Blog")
        #expect(imported.pelican.tagsCommand == "x")
        #expect(imported.aiActions == Configuration.defaultActions)
    }

    @Test func savedProfilesRoundTrip() throws {
        var config = Configuration.default
        config.editor.monospaced = true
        try store.save(config, as: "Mono")
        #expect(try store.load("Mono") == config)
        #expect(throws: ProfileError.self) { try store.load("Missing") }
    }

    @Test func cliTokenIsStableAndPrivate() throws {
        let token = try store.cliToken()
        #expect(token.count == 32)
        #expect(try store.cliToken() == token)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: directory.appendingPathComponent("cli-token").path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test func supportDirectoryOverride() {
        let custom = ProfileStore.defaultDirectory(environment: ["AARON_SUPPORT_DIR": "~/x"], folderName: "Aaron")
        #expect(custom.path == NSHomeDirectory() + "/x")
        let normal = ProfileStore.defaultDirectory(environment: [:], folderName: "Aaron Debug")
        #expect(normal.path.hasSuffix("Library/Application Support/Aaron Debug"))
    }
}
