# Windows, tabs and restoring the session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Profile menu last in the toolbar; the same file open in several windows, kept in sync with a note; ⌘T / ⌘1–⌘9 tabs; restoring the last normal session.

**Architecture:** An `NSDocumentController` subclass lets a second copy of an open file open (spike first). Copies are separate SwiftUI documents; NSDocument's own file presenting reloads a copy when another saves, and the editor applies the reload as a minimal, selection-preserving edit. New tabs and restored windows reuse the existing hand-off pattern (`pendingProfiles`/`pendingTakeovers`): a pending placement is picked up by the window that appears. Session state is plain Codable in AaronCore, saved to the support folder by normal sessions only.

**Tech Stack:** Swift 6 (strict concurrency, warnings are errors), SwiftUI DocumentGroup, AppKit, XcodeGen, Swift Testing (packages), XCTest (app), Debug smoke harness.

**Spec:** `docs/superpowers/specs/2026-11-02-windows-and-tabs-design.md`

## Global Constraints

- Never a Co-Authored-By (or other attribution) line in commit messages.
- No user website or domain in the repo; generic examples only.
- UI automation (XCUITest) needs the user's approval; use the smoke harness.
- "Always get confirmation if data would be lost."
- Commits grouped by goal, in the order of the tasks below.
- After adding a Swift file to the app: `cd App && xcodegen generate`.
- Test commands:
  - packages: `swift test`
  - app: `cd App && xcodebuild -project Aaron.xcodeproj -scheme Aaron -derivedDataPath ../build/DerivedData test -only-testing:AaronTests`
  - smoke: `scripts/smoke-test.sh` (or `SKIP_BUILD=1 scripts/smoke-test.sh NAME`)

## Review Focus

1. A reload in a reading copy must not leave it marked edited: otherwise the writing copy's next save hits "changed by another application".
2. Quitting must not erase the saved session while windows close one by one.
3. A first launch by the `aaron` command (to create the token) must not count as a normal start.
4. The file panel takeover and `aaron --profile` hand-off still work when two copies of one file exist.
5. Untitled documents with text still ask at quit once macOS window restoration is off.

---

### Task 1: Toolbar order

**Files:** Modify `App/Sources/Aaron/DocumentWindow.swift` (toolbar group); docs that describe the toolbar order (`grep -rn "toolbar" docs/user`).

- [ ] Move `ProfileMenu(model: model)` after the Review toggle.
- [ ] Build and run smoke `profiles` and `reader`. Expected: PASS.
- [ ] Commit "Put the profile menu last in the toolbar".

### Task 2: Spike — a second copy of an open file

**Files:** Create `App/Sources/Aaron/DocumentController.swift`; modify `AaronApp.swift` (instantiate it in `AppDelegate.init` or `applicationWillFinishLaunching`, before anything touches `NSDocumentController.shared`); `DebugHarness.swift`; create `App/SmokeTests/copies.json`.

**Interfaces:** Produces `final class DocumentController: NSDocumentController`, which overrides `document(for:)` to return nil so `openDocument(withContentsOf:display:)` always makes a new document.

- [ ] Harness: step `openAgain: true` (calls `appModel.openDocument(model.fileURL!)`), expectation `copiesOf: Int` (windows whose `fileURL` is the same file as the first window's).
- [ ] `copies.json`: open again, wait 2, expect `copiesOf: 2`, `windowCount: 2`. Run it. Expected before the controller: FAIL (1 copy).
- [ ] Add the controller. Check `NSDocumentController.shared is DocumentController` in the harness log. Run. Expected: PASS.
- [ ] Extend the spike: in the first copy type, then `save: true` (new step: sends `NSDocument.save(_:)` through the window's document), wait 3; expect the other copy's text contains the typed text (new expectation `allCopiesContain: String`). Find out whether NSDocument reloads the other copy by itself; if not, the copies need their own presenter (`NSFilePresenter` in the window model) — ledger which.
- [ ] **If no copy opens, or saving/closing/reloading breaks: STOP and report to the user** (agreed). Otherwise commit "Allow opening a file that is already open".

### Task 3: Opening rules for copies

**Files:** `WindowTakeover.swift`, `OpenRequestHandling.swift`, `FilePanel.swift`, `App/Tests/WindowTakeoverTests.swift`, `docs/user/files.md`, `docs/user/command-line.md`.

**Interfaces:** `PanelOpenResult` loses `.broughtForward`. `openFromPanel(_:from:inNewWindow:)`: a plain click on the window's own file → `.nothing`; `inNewWindow` on its own file → `.newWindow`; a file open elsewhere → opens as for any file.

- [ ] Tests first: replace `testAlreadyOpenFileIsNotReopened` with `testFileOpenElsewhereOpensAgain` (replace → `.replaced`, new window → `.newWindow`, `openDocument` called); add `testOwnFileInNewWindowOpensCopy`; keep `testSameFileDoesNothing` for the plain click. Add `testCLIProfileForOpenFileOpensNewCopy` (no profile change on the existing window, pending profile recorded, `openDocument` called). Run. Expected: FAIL.
- [ ] Implement; remove `windowShowing` if unused. Run app tests. Expected: PASS.
- [ ] Docs: files.md "already open" rule, command-line.md. Commit "Open files again instead of bringing their window forward".

### Task 4: Reloading a copy keeps selection and undo

**Files:** `EditorView.swift` (`EditorController.documentChanged`), `Sources/AaronCore/` new `TextDiff.swift` + tests.

**Interfaces:** `public enum TextDiff { static func change(from: String, to: String) -> (range: NSRange, replacement: String)? }` — common prefix/suffix in UTF-16, nil when equal. `public static func adjust(_ selection: NSRange, for change: …) -> NSRange` — positions before the change stay, after it shift by the length delta, inside it clamp to the change's end.

- [ ] Tests first (Swift Testing, `TextDiffTests`): equal → nil; insert in middle; delete at end; replace with emoji/diacritics (UTF-16 counts); selection before/after/inside. Run `swift test --filter TextDiff`. Expected: FAIL, then implement, PASS.
- [ ] `documentChanged` applies the change through the text storage with undo registration (one undo step, action name "Reload"), keeps the adjusted selection and scroll position, and does **not** write back to the document binding (the binding already holds the text). 
- [ ] Smoke `copies.json`: after the reload, the reading copy's document must not be edited (new expectation `copiesEdited: false`, from `hostWindow.isDocumentEdited` of the non-typing copies); then save the typing copy again and expect no error alert. If an undoable reload necessarily marks the document edited, fall back to clearing that copy's undo history on reload (allowed by the spec) and ledger the ruling.
- [ ] Commit "Reload other copies of a file when it is saved".

### Task 5: The "also open" note

**Files:** `DocumentWindowModel.swift`, `AppModel.swift`, `WindowTakeover.swift` (`WindowAccessor`: tell the app model when the host window closes), create `App/Sources/Aaron/CopyNote.swift`, `DocumentWindow.swift`, `App/Tests/CopyNoteTests.swift`, `docs/user/` (new section, see Task 8).

**Interfaces:** `DocumentWindowModel.copyCount: Int` (set by `AppModel.refreshCopies()`, called on register, file URL change and window close); `dismissCopyNote()`; `showsCopyNote: Bool` = `copyCount > 1 && copyCount > dismissedAtCount`. Text: "Also open in another window. Edits there appear here after they're saved."

- [ ] Tests first: one copy → no note; two copies → both show; dismiss in one → only the other shows; third copy → shows again in both; back to one → none. Run. Expected: FAIL; implement; PASS.
- [ ] View: slim bar above the split view with a close button (`xmark`), accessibility identifier `copyNote`. Harness expectation `showsCopyNote: Bool`; add to `copies.json`.
- [ ] Commit "Tell the user when a file is open in another window".

### Task 6: New tab and tab keys

**Files:** `AppCommands.swift`, `AppModel.swift`, `DocumentWindow.swift`, `DocumentWindowModel.swift` (`hostWindow` didSet), create `App/Sources/Aaron/Tabs.swift`, `App/Tests/TabsTests.swift`, harness, `App/SmokeTests/tabs.json`.

**Interfaces:**
- `AppModel.pendingNewTabs: [NewTab]`, `struct NewTab { profile: String; weak parent: NSWindow?; created: Date }`; `func newTab(from: DocumentWindowModel?)` records one and calls `newDocument` (`NSDocumentController.shared.newDocument(nil)`, replaceable in tests); `func newTab(forUntitled:) -> NewTab?` returned once, expiring like takeovers. The untitled window takes its profile and, once it has a host window, `parent.addTabbedWindow(new, ordered: .above)` and becomes key.
- `enum TabKeys { static func index(forKey n: Int, tabCount: Int) -> Int? }`: 1–8 → n-1 if < count; 9 → last; window without tabs → nil.
- `aaron --profile NAME` without files reuses the untitled hand-off (no parent): `OpenRequest` accepts no paths when a profile is given.
- File ▸ New Tab ⌘T; Window menu "Select Tab 1…8", "Select Last Tab" (⌘1–⌘9), hidden or listed — listed under the Window menu *(ruling: visible keys are discoverable)*. Remove Show Fonts' ⌘T if SwiftUI adds it.

- [ ] Tests first: `TabKeys` mapping; `newTab` records the window's profile and parent; untitled hand-off returned once and expires; `OpenRequest` with profile and no path parses, without either does not (package test). Run. Expected: FAIL; implement; PASS.
- [ ] Untitled replacement from the file panel: verify an empty untitled tab is replaced without a prompt (existing takeover path). Harness: step `newTab: true`, `selectTab: Int`; expectations `tabCount`, `selectedTabIndex`, `windowProfiles`. `tabs.json`: profile switch to a second profile, newTab, expect two tabs and the new one with that profile; selectTab 1; expect index 0; `openFile` from the untitled tab, expect it replaced (tab count 2).
- [ ] Manual check (no UI automation): drag-reorder and drag-out keep profile and panes — ask the user in the final report if not checked.
- [ ] Commit "Add New Tab and tab selection keys".

### Task 7: Session model and settings (AaronCore)

**Files:** create `Sources/AaronCore/Session.swift`, `Tests/AaronCoreTests/SessionTests.swift`; modify `ProfileStore.swift` (+ tests).

**Interfaces:**
- `public struct SavedSession: Codable, Equatable { var groups: [SavedTabGroup]; var frontGroup: Int? }`, `SavedTabGroup { var frame: String (NSStringFromRect); var tabs: [SavedTab]; var selected: Int }`, `SavedTab { var path: String; var profile: String }`.
- `ProfileStore.sessionURL` = `<support>/session.json`; `loadSession() -> SavedSession?`, `saveSession(_:) throws`; `reopenWindows() -> Bool` (default true), `setReopenWindows(_:) throws` stored as `reopenWindows` in `profiles.json` next to `defaultProfile` (keep `defaultProfile` when writing either).
- `public enum LaunchKind { case normal, withRequest }` and `static func decide(isDefaultLaunch: Bool, arguments: [String]) -> LaunchKind`: `withRequest` if `!isDefaultLaunch` or arguments contain `--aaron-cli-launch`.
- `SavedSession.pruned(fileExists:)` drops missing files and empty groups, clamps `selected`.

- [ ] Tests first for all of the above (round trip, defaults, `reopenWindows` keeps `defaultProfile`, pruning, decide). Run `swift test`. Expected: FAIL; implement; PASS.
- [ ] Commit "Add the saved session model".

### Task 8: Saving and restoring the session

**Files:** `AaronApp.swift` (AppDelegate: launch kind from `applicationDidFinishLaunching` userInfo `NSApplication.launchIsDefaultUserInfoKey`; `applicationShouldTerminate` writes the final session and freezes saving), create `App/Sources/Aaron/SessionRestore.swift`, `AppModel.swift`, `WindowTakeover.swift` (`WindowAccessor` reports move/resize/close), `SettingsView.swift` (Profiles tab: "Reopen windows from last time" toggle in an app-wide "Startup" section), `App/Sources/Aaron/Resources/aaron`, smoke runner, `App/SmokeTests/restore.json` + `restore.session.json`, `App/Tests/SessionRestoreTests.swift`.

**Interfaces:**
- `AppModel.launchKind`, `func currentSession() -> SavedSession` (from `NSApp.orderedWindows` → models by `hostWindow`; tab groups by `tabbedWindows` order; skip untitled), `scheduleSessionSave()` (debounced 1 s, only for normal launches, stops after termination started), `func restore(_:) async` (per group: open each tab's file with its profile through `pendingProfiles`, wait for its model's host window (5 s timeout), first tab gets the frame, the rest `addTabbedWindow(.above)` in order; then select the saved tab and order the front group front). Placement goes through a pending record picked up in `hostWindow` didSet, like takeovers.
- macOS restoration off for document windows (`isRestorable = false` in `WindowAccessor`) so only Aaron restores.
- Script: no arguments → `open -a "$app"`; `--profile` without files → URL with profile only; the token-creating first launch passes `--args --aaron-cli-launch`. Usage text updated.

- [ ] Tests first: `currentSession` encoding from stub models is covered by Task 7; here test `restore` ordering with a fake `openDocument` that creates models (profiles assigned, groups formed in order), and that a non-normal launch never saves. Run. Expected: FAIL; implement; PASS.
- [ ] Smoke runner: when `App/SmokeTests/NAME.session.json` exists, copy it to `support/session.json` (with `$WORK` substituted) and launch without a document and without `-ApplePersistenceIgnoreState`. Harness attaches to the first window that appears. `restore.json`: expect `windowCount`, `windowProfiles`, `tabCount` as in the saved session. Also run the CLI scenario to confirm `aaron FILE` still works.
- [ ] Manual check of quitting with untitled text: the prompt appears (Review Focus 5); if it doesn't, add `applicationShouldTerminate` review via `NSDocumentController.reviewUnsavedDocuments`.
- [ ] Commit "Reopen the last session on a normal start".

### Task 9: Docs

**Files:** `docs/user/` (new `windows-and-tabs.md`, README index, getting-started, keyboard-shortcuts, settings, command-line, files, profiles), `docs/decisions.md` (new entries), `docs/developer/testing.md` (new steps and expectations, session scenarios).

- [ ] Write; check links (`grep -o "([a-z-]*\.md)" docs/user/*.md`). Commit "Document windows, tabs and session restore".
