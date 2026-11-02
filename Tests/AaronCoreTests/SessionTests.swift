import Foundation
import Testing
@testable import AaronCore

struct SessionTests {
    func store() -> ProfileStore {
        ProfileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("aaron-session-\(UUID().uuidString)"))
    }

    let session = SavedSession(groups: [
        SavedTabGroup(frame: "{{10, 20}, {800, 600}}",
                      tabs: [SavedTab(path: "/a.md", profile: "Default"), SavedTab(path: "/b.md", profile: "Blog")],
                      selected: 1),
        SavedTabGroup(frame: "{{0, 0}, {500, 400}}", tabs: [SavedTab(path: "/c.md", profile: "Reader")], selected: 0),
    ], frontGroup: 1)

    @Test func sessionRoundTrips() throws {
        let store = store()
        #expect(store.loadSession() == nil)
        try store.saveSession(session)
        #expect(store.loadSession() == session)
    }

    @Test func reopenWindowsDefaultsOn() {
        #expect(store().reopenWindows())
    }

    @Test func reopenWindowsKeepsTheDefaultProfile() throws {
        let store = store()
        try store.prepare()
        try store.save(.default, as: "Blog")
        try store.setDefaultProfile("Blog")
        try store.setReopenWindows(false)
        #expect(!store.reopenWindows())
        #expect(store.defaultProfileName() == "Blog")
        try store.setDefaultProfile(ProfileStore.initialProfileName)
        #expect(!store.reopenWindows(), "setting the default keeps the reopen setting")
    }

    @Test func pruningDropsMissingFilesAndEmptyGroups() {
        let pruned = session.pruned { $0 != "/b.md" && $0 != "/c.md" }
        #expect(pruned.groups.count == 1)
        #expect(pruned.groups[0].tabs.map(\.path) == ["/a.md"])
        #expect(pruned.groups[0].selected == 0)
        #expect(pruned.frontGroup == nil, "the front group was dropped")
    }

    @Test func pruningKeepsTheSelectedTab() {
        let pruned = session.pruned { $0 != "/a.md" }
        #expect(pruned.groups[0].tabs.map(\.path) == ["/b.md"])
        #expect(pruned.groups[0].selected == 0)
        #expect(pruned.frontGroup == 1)
    }

    @Test func launchKind() {
        #expect(LaunchKind.decide(isDefaultLaunch: true, arguments: ["Aaron"]) == .normal)
        #expect(LaunchKind.decide(isDefaultLaunch: false, arguments: ["Aaron"]) == .withRequest)
        #expect(LaunchKind.decide(isDefaultLaunch: true, arguments: ["Aaron", LaunchKind.commandLineFlag]) == .withRequest)
        #expect(LaunchKind.decide(isDefaultLaunch: true, arguments: ["Aaron"], openedSomething: true) == .withRequest)
        #expect(LaunchKind.decide(isDefaultLaunch: true, arguments: ["Aaron", "/tmp/a.md"]) == .withRequest)
        #expect(LaunchKind.decide(isDefaultLaunch: true, arguments: ["Aaron", "-ApplePersistenceIgnoreState", "YES"]) == .normal)
        #expect(LaunchKind.decide(isDefaultLaunch: true,
                                  arguments: ["Aaron", "-NSDocumentRevisionsDebugMode", "YES", "a.md"]) == .withRequest)
    }
}
