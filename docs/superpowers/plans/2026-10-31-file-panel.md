# File Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A per-profile file panel on the left of each document window that lists the Markdown files under the profile's root folder, with a name filter, click-to-load and ⌘-click/middle-click to open in a new window.

**Architecture:** A new package module `AaronFiles` holds everything testable without a window: building the pruned tree from a list of paths, filtering, the Spotlight query and the fallback folder reader behind one protocol. The app gets a per-window `FilePanelModel` owned by `DocumentWindowModel`, a `FilePanel` view as the first pane of the existing `HSplitView`, and an `AppModel` hand-off that lets a newly opened document window take over the old one's place and state.

**Tech Stack:** Swift 6.2, SwiftUI + AppKit, `NSMetadataQuery` (Spotlight), Swift Testing (package), XCTest (hosted), Debug smoke harness, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-31-file-panel-design.md`

## Global Constraints

- macOS 26+, warnings are errors; package tests print no warnings.
- Profile keys: `panes.files` (default `true`), `files.root` (default `"~"`; empty means home), `files.extensions` (default `["md", "markdown"]`; case-insensitive, leading dot dropped, empty list means defaults), `files.ignoredFolders` (default `["node_modules"]`).
- Hidden = name starts with `.` or `URLResourceValues.isHidden`. iCloud Drive path: `~/Library/Mobile Documents/com~apple~CloudDocs`, shown as a top entry named **iCloud Drive** when under the root.
- Shortcut: **View ▸ Show/Hide Files** ⌃⌘S. The files pane doesn't count for the editor/preview rule.
- Sorting: folders first, then files, `localizedStandardCompare`.
- Confirmation copy: title `Open “<new>” in this window?`; message `The <n> open suggestion(s) for “<current>” will be lost.` or `The running “<action>” action will be cancelled.`; buttons **Open in New Window** (default), **Replace**, **Cancel**.
- Empty state copy: `No Markdown files here`, `Folder not found`, fallback note `Search needs Spotlight, which doesn't index this folder.`
- Commit messages carry no co-author lines (user's standing rule).
- Every *(Claude's call)* in the spec gets a `docs/decisions.md` entry.

## Review Focus

1. **A home-folder root with tens of thousands of results** must not freeze the window: results are read in batches off the query's notifications and the tree is rebuilt at most twice a second (Task 2: `SpotlightFileSource` uses `notificationBatchingInterval`; Task 1 test builds a 20 000-path tree under 1 s).
2. **Files whose names differ only by case or diacritics, or contain spaces/`#`/`%`/non-ASCII** must be listed and openable (Task 1 tree test with such names; Task 6 smoke test opens `ščž #1.md`).
3. **The root folder deleted or renamed while windows show it** must show `Folder not found`, not crash (Task 3 model test).
4. **Clicking the file the window already shows, or a file already open in another window** must not open a duplicate (Task 5 hosted tests).
5. **A profile file with `"extensions": []` or `".MD"`** must still find `.md` files (Task 1 settings tests).

---

### Task 1: Settings, tree building and filtering

**Files:**
- Modify: `Sources/AaronCore/Configuration.swift` (add `FileSettings`, `panes.files`)
- Create: `Sources/AaronFiles/FileTree.swift`
- Modify: `Package.swift` (target `AaronFiles` depending on `AaronCore`, test target `AaronFilesTests`)
- Test: `Tests/AaronCoreTests/ConfigurationTests.swift`, `Tests/AaronFilesTests/FileTreeTests.swift`

**Interfaces:**
- Produces:
  - `PaneSettings.files: Bool` (default `true`, decoded if present).
  - `public struct FileSettings: Codable, Equatable, Sendable { root: String; extensions: [String]; ignoredFolders: [String]; var rootURL: URL; var normalizedExtensions: Set<String> }`, `Configuration.files`.
  - `public enum FileNode: Identifiable, Hashable { case folder(FileFolder), file(URL) }` and `public struct FileFolder { url: URL; name: String; children: [FileNode]; isICloudDrive: Bool }`; `id` is the URL.
  - `public struct FileTreeBuilder { init(root: URL, ignoredFolders: [String], iCloudDrive: URL?, isHidden: (URL) -> Bool); func build(_ files: [URL]) -> [FileNode] }`.
  - `public struct FileMatch { url: URL; name: String; folder: String }` and `public func filterFiles(_ files: [URL], root: URL, query: String) -> [FileMatch]`.

- [ ] **Step 1: Write failing tests** — `effectiveExtensionsNormalise` (`[".MD", " markdown"]` → `{"md","markdown"}`; `[]` → defaults), `rootURLExpandsTildeAndEmpty` (`""` and `"~"` → home), `panesFilesDefaultsOn`; tree: `prunesToFoldersWithFiles` (only folders on a file's path exist), `skipsIgnoredAndHidden` (`node_modules/x.md`, `.git/x.md`, a path the `isHidden` closure flags), `sortsFoldersFirstFinderStyle` (`a10` after `a2`), `iCloudDriveBecomesTopEntry`, `filesOutsideRootIgnored`, `buildsLargeTreeQuickly` (20 000 paths < 1 s); filter: `matchesNameOnlyIgnoringCaseAndDiacritics` (`"cez"` matches `Čež.md`, folder name never matches), `matchShowsFolderRelativeToRoot`.
- [ ] **Step 2: Run** `swift test --filter "FileTree|Configuration"` — expect failures (missing types).
- [ ] **Step 3: Implement.** `isHidden` is consulted once per folder path (memoised in `build`). The iCloud folder is exempt from the hidden check for itself and its ancestors.
- [ ] **Step 4: Run** the same command — PASS.
- [ ] **Step 5: Commit** `Add file settings and the file tree builder`.

### Task 2: File sources (Spotlight and fallback)

**Files:**
- Create: `Sources/AaronFiles/FileSource.swift`, `Sources/AaronFiles/SpotlightFileSource.swift`, `Sources/AaronFiles/FolderReader.swift`
- Test: `Tests/AaronFilesTests/FolderReaderTests.swift`

**Interfaces:**
- Produces:
  - `@MainActor public protocol FileSource: AnyObject { func start(root: URL, extensions: Set<String>, update: @escaping @MainActor (FileSourceEvent) -> Void); func stop() }`
  - `public enum FileSourceEvent { case progress([URL]), finished([URL]), updated([URL]), notIndexed }` — every case carries the full current list.
  - `SpotlightFileSource: FileSource` — `NSMetadataQuery`, scope `[root]`, predicate `kMDItemFSName LIKE[c] '*.<ext>'` OR-ed, `notificationBatchingInterval = 0.5`; on finish with 0 results runs a one-off "any item" query (`kMDItemFSName LIKE '*'`) and sends `.notIndexed` if that is empty too.
  - `public struct FolderReader { func contents(of folder: URL, extensions: Set<String>, ignoredFolders: [String]) -> [FileNode] }` for fallback browsing (no hidden, no packages, only Markdown files, sorted like the tree).
- [ ] **Step 1: Failing tests** for `FolderReader` on a temporary folder: lists subfolders and `.md` files, skips `.hidden`, `node_modules`, `x.app`, `notes.txt`.
- [ ] **Step 2–4:** run, implement, run (`swift test --filter FolderReader`). `SpotlightFileSource` has no unit test (Spotlight doesn't reliably index temp folders); it is covered by the manual check in Task 6.
- [ ] **Step 5: Commit** `Add Spotlight and fallback file sources`.

### Task 3: Panel model and panes

**Files:**
- Create: `App/Sources/Aaron/FilePanelModel.swift`
- Modify: `App/Sources/Aaron/DocumentWindowModel.swift`, `App/project.yml` (add `AaronFiles`)
- Test: `App/Tests/FilePanelModelTests.swift`, `App/Tests/DocumentWindowModelTests.swift`

**Interfaces:**
- Consumes: Task 1 and 2 types.
- Produces:
  - `@MainActor @Observable final class FilePanelModel { init(source: @escaping () -> FileSource); enum State { case loading, ready, empty, fallback, missing }; var state; var nodes: [FileNode]; var expanded: Set<URL>; var filter: String; var matches: [FileMatch]; var root: URL; func configure(_ settings: FileSettings); func reveal(_ file: URL?); func children(of folder: URL) -> [FileNode] }` (fallback reads with `FolderReader` on expand).
  - `DocumentWindowModel.files: FilePanelModel`, `showFiles: Bool`, `applyPanes()` sets `showFiles`; `configurationChanged` calls `files.configure` when `files` settings changed; `documentOpened`/`fileURLChanged` call `files.reveal`.
  - `DocumentWindowModel.fileSource: () -> FileSource` static factory, replaced in tests and the harness.
- [ ] **Step 1: Failing tests** with a fake `FileSource`: `finishedResultsBuildTree`, `revealExpandsAncestors`, `filterUsesFoundFiles`, `notIndexedSwitchesToFallback` (filter disabled → `matches` empty), `missingRootShowsMissing` (root path doesn't exist → `.missing`, no source started), `emptyIndexedRootShowsEmpty`, `reconfigureRestartsSource`; window model: `profileSwitchAppliesFilesPane`.
- [ ] **Step 2–4:** run `xcodebuild … test -only-testing:AaronTests`, implement, run.
- [ ] **Step 5: Commit** `Add the file panel model`.

### Task 4: Panel view, panes UI and settings

**Files:**
- Create: `App/Sources/Aaron/FilePanel.swift`
- Modify: `App/Sources/Aaron/DocumentWindow.swift`, `App/Sources/Aaron/AppCommands.swift`, `App/Sources/Aaron/SettingsView.swift`

**Interfaces:**
- Consumes: `FilePanelModel`; `FilePanelActions` from Task 5 (`open(_ url: URL, inNewWindow: Bool)`, `setRoot(_ url: URL?)`).
- Produces: `FilePanel(model: DocumentWindowModel)` as the first `HSplitView` child when `showFiles` (min 200, ideal 260); header menu (**Choose Root Folder…**, **Use Home Folder**); filter field (↓ moves to results, Return opens, Esc clears); tree via recursive `DisclosureGroup` bound to `expanded`; `List` selection derived from the window's `fileURL` and its setter opening the file (⌘ held → new window); `MiddleClickCatcher` overlay (an `NSView` whose `hitTest` returns itself only while `NSApp.currentEvent?.type == .otherMouseDown/Up`); context menus per spec; toolbar **Files** toggle (`sidebar.left`), **View ▸ Show/Hide Files** ⌃⌘S; **Settings ▸ General ▸ Files** (root + **Choose…**, extensions, ignored folders, comma-separated) and **Files** switch in **Panes**.
- [ ] **Step 1:** build the app (`xcodebuild … build`) — compiles without warnings.
- [ ] **Step 2:** run hosted and smoke tests — existing scenarios still PASS.
- [ ] **Step 3: Commit** `Show the file panel`.

### Task 5: Opening files from the panel

**Files:**
- Create: `App/Sources/Aaron/WindowTakeover.swift` (`AppModel` extension, `WindowAccessor` view)
- Modify: `App/Sources/Aaron/DocumentWindow.swift`, `App/Sources/Aaron/DocumentWindowModel.swift`, `App/Sources/Aaron/AppModel.swift`
- Test: `App/Tests/WindowTakeoverTests.swift`

**Interfaces:**
- Produces:
  - `DocumentWindowModel.hostWindow: NSWindow?` (weak, set by `WindowAccessor`), `hasUnfinishedReview: Bool`, `reviewLossMessage: String`.
  - `struct Takeover { profile: String; panes: PaneSettings; expanded: Set<URL>; filter: String; replacing: WeakWindowRef }`, `AppModel.pendingTakeovers`, `func takeover(for: URL?) -> Takeover?` (returned once, matched with `isSameFile`).
  - `AppModel.openFromPanel(_ file: URL, from window: DocumentWindowModel, inNewWindow: Bool)`: same file → nothing; open in another window → `hostWindow.makeKeyAndOrderFront`; new window → `pendingProfiles` + `openDocument`; replace → `pendingTakeovers` + `openDocument`. The confirmation is asked by the view before calling with `inNewWindow: false`.
  - When the new window's `hostWindow` is set and a takeover is pending: in a tab group `old.addTabbedWindow(new, ordered: .above)`, otherwise `new.setFrame(old.frame, display: true)`; then `old.performClose(nil)`.
- [ ] **Step 1: Failing tests** (with `openDocument` replaced): `sameFileDoesNothing`, `alreadyOpenFileIsNotReopened`, `newWindowCarriesProfile`, `replaceRecordsTakeoverWithState`, `takeoverIsReturnedOnce`, `unfinishedReviewDetected` (open suggestion → true; only accepted/dismissed → false; running action → true) and `reviewLossMessage` copy.
- [ ] **Step 2–4:** run, implement, run.
- [ ] **Step 5: Commit** `Open files from the file panel`.

### Task 6: Harness, smoke test, docs

**Files:**
- Modify: `App/Sources/Aaron/DebugHarness.swift` (step `openFile: "<path relative to root>"` with optional `newWindow: true`; expectations `filesState`, `filesVisible: [relative paths of visible files]`, `filesMatches`), `scripts/smoke-test.sh` (replace `$WORK` in profiles), `App/SmokeTests/config.json` (`"files": {"root": "$WORK"}`)
- Create: `App/SmokeTests/files.json`, `App/SmokeTests/files.files/` (`notes/a.md`, `notes/ščž #1.md`, `empty/readme.txt`, `node_modules/x.md`)
- Create: `docs/user/files.md`; modify `docs/user/README.md`, `profiles.md`, `settings.md`, `getting-started.md`, `keyboard-shortcuts.md`, `docs/decisions.md`, `docs/developer/testing.md`
- [ ] **Step 1:** write `files.json`: expect a state of `ready` or `fallback` (temp folders may not be indexed), visible files contain `notes/a.md`, not `node_modules/x.md` or anything under `empty`; `openFile: "notes/ščž #1.md"` → `windowProfiles` has `ščž #1.md` and `windowCount` 1.
- [ ] **Step 2:** run `scripts/smoke-test.sh` — all PASS.
- [ ] **Step 3:** manual check of Spotlight on a real indexed folder (e.g. `docs/` of this repo) via a Debug run; record the result in `docs/developer/testing.md`.
- [ ] **Step 4: Commit** `Document the file panel; add its smoke test`.
