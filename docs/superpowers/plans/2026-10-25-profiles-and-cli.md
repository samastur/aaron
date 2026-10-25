# Configuration Profiles and the `aaron` Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Named configuration profiles (one default, switchable per window) and an `aaron [--profile NAME] FILE...` command that opens files in a running or newly started Aaron.

**Architecture:** A file-based `ProfileStore` in AaronCore owns the support folder (profiles, default, migration, CLI token). `AppModel` keeps all profiles in memory, saves each on its own, and tells registered windows when their profile changes; `DocumentWindowModel` gets a `profileName`. The command is a zsh script in the app bundle that validates arguments and sends a token-carrying `aaron://open` URL to its own app copy, which `AppModel` turns into document opens.

**Tech Stack:** Swift 6.2, SwiftUI `DocumentGroup` + AppKit, Swift Testing (package), XCTest (hosted + UI), XcodeGen, zsh.

**Spec:** `docs/superpowers/specs/2026-10-25-profiles-and-cli-design.md`

## Global Constraints

- macOS 26+, warnings are errors (`SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`); package tests must print no warnings.
- Support folder layout: `profiles.json` (`{"defaultProfile": "<name>"}`) and `Profiles/<name>.json`; a profile's name is its file name without `.json`.
- Release: bundle id `net.gaivo.Aaron`, folder `~/Library/Application Support/Aaron/`. Debug: bundle id `net.gaivo.Aaron.debug`, display name *Aaron Debug*, folder `~/Library/Application Support/Aaron Debug/`.
- `AARON_SUPPORT_DIR` overrides the folder; `AARON_CONFIG_PATH` is removed everywhere.
- Migration: no `Profiles/` → create it with **Default** from `config.json` (or built-in defaults); rename `config.json` to `config.json.migrated`.
- Profile names: non-empty after trimming, unique ignoring case, no `/` or `:`, not starting with `.`.
- The command installs only to `~/.local/bin` (never a Homebrew prefix, never `/usr/local/bin`).
- URL requests must carry the token from `<support>/cli-token` (mode 0600); others are ignored and logged.
- Never mention the author's website or their own tools from other repositories in the repo; examples use a profile named *Blog*, `~/blog`, `scripts/render-post` etc.
- Commit messages carry no co-author lines.
- Every *(Claude's call)* in the spec gets a `docs/decisions.md` entry.

## Review Focus

1. **A profile file that fails to parse** must not be overwritten and must not stop other profiles from loading or saving (Task 1 store test, Task 3 hosted test).
2. **Renaming the profile a window uses, or the default** must keep windows and `profiles.json` pointing at it (Task 1, Task 3).
3. **File paths with spaces, `&`, `#`, `%` and non-ASCII letters** must survive script → URL → app (Task 2 parser round-trip, Task 6 script test).
4. **`aaron` run while Aaron is not running yet** (no token file) must start the app and still open the file (Task 6 step: token wait; Task 9 smoke).
5. **Opening a file that is already open with `--profile`** must switch that window instead of opening a second one (Task 5 hosted test).

---

### Task 1: ProfileStore in AaronCore

**Files:**
- Create: `Sources/AaronCore/ProfileStore.swift`
- Modify: `Sources/AaronCore/Configuration.swift` (remove `ConfigurationStore.environmentKey`/`defaultURL`; keep `load(from:)`/`save(_:to:)`)
- Test: `Tests/AaronCoreTests/ProfileStoreTests.swift`; update `Tests/AaronCoreTests/ConfigurationTests.swift` (drop `defaultURL` tests)

**Interfaces:**
- Produces:
  - `public struct ProfileStore: Sendable { public let directory: URL; public init(directory: URL) }`
  - `public static let environmentKey = "AARON_SUPPORT_DIR"`
  - `public static func defaultDirectory(environment: [String: String], folderName: String) -> URL` (env override, else `~/Library/Application Support/<folderName>`)
  - `public var profilesDirectory: URL`, `public func url(for name: String) -> URL`
  - `public func prepare() throws` (migration; empty `Profiles/` gets Default)
  - `public func names() -> [String]` (sorted with `localizedStandardCompare`)
  - `public func load(_ name: String) throws -> Configuration`, `public func save(_ c: Configuration, as name: String) throws`
  - `public func rename(_ old: String, to new: String) throws` (updates `profiles.json` when `old` was default)
  - `public func delete(_ name: String) throws` (throws `ProfileError.cannotDeleteDefault` / `.cannotDeleteLast`)
  - `public func defaultProfileName() -> String` (from `profiles.json`; missing/unknown → first of `names()`)
  - `public func setDefaultProfile(_ name: String) throws`
  - `public func importProfile(from url: URL, as name: String) throws` (lenient decode, then save)
  - `public func cliToken() throws -> String` (create 32 random hex chars, mode 0600, if missing)
  - `public static func validationError(for name: String, existing: [String], ignoring: String? = nil) -> String?` (nil = valid)
  - `public enum ProfileError: LocalizedError { case invalidName(String), cannotDeleteDefault, cannotDeleteLast, notFound(String) }`

- [ ] **Step 1: Write failing tests** in `ProfileStoreTests` (temp directory per test):
  - `migratesConfigJSONIntoDefault`: write `config.json` with `{"editor":{"fontSize":20}}`; `prepare()`; `#expect(names() == ["Default"])`, `load("Default").editor.fontSize == 20`, `config.json` gone, `config.json.migrated` exists.
  - `freshFolderGetsBuiltinDefault`: `prepare()` → `names() == ["Default"]`, `load("Default") == .default`.
  - `prepareDoesNotMigrateTwice`: after first `prepare()`, write a new `config.json`, `prepare()` again → Default unchanged, `config.json` still there.
  - `emptyProfilesFolderGetsDefault`.
  - `defaultFallsBackToFirstName`: profiles `Blog`, `Plain`, no `profiles.json` → `"Blog"`; `profiles.json` naming `Gone` → `"Blog"`.
  - `renameKeepsDefault`: default `Blog`, `rename("Blog", to: "Site")` → `defaultProfileName() == "Site"`, file `Blog.json` gone.
  - `deleteRefusesDefaultAndLast`.
  - `nameValidation`: `""`, `"  "`, `"a/b"`, `"a:b"`, `".hidden"`, `"plain"` with existing `["Plain"]` all give non-nil; `"Plain"` with `ignoring: "Plain"` gives nil; `"Blog 2"` nil.
  - `unreadableProfileDoesNotBreakOthers`: `Bad.json` = `"{ broken"`, `Good.json` valid → `names()` contains both, `load("Bad")` throws, `load("Good")` succeeds.
  - `importIsLenient`: import `{"pelican":{"tagsCommand":"x"}}` as `Blog` → `load("Blog").pelican.tagsCommand == "x"`, `aiActions == Configuration.defaultActions`.
  - `cliTokenIsStableAndPrivate`: two calls equal, 32 chars, file permissions `0o600`.
  - `supportDirectoryOverride`: `defaultDirectory(environment: ["AARON_SUPPORT_DIR": "~/x"], folderName: "Aaron").path == NSHomeDirectory() + "/x"`; without env ends in `Library/Application Support/Aaron Debug` for `folderName: "Aaron Debug"`.
- [ ] **Step 2:** `swift test --filter ProfileStoreTests` → fails to compile (`ProfileStore` missing).
- [ ] **Step 3:** Implement `ProfileStore.swift`; remove `ConfigurationStore.defaultURL`/`environmentKey` and their tests.
- [ ] **Step 4:** `swift test` → all pass, no warnings. (App target will not compile until Task 3; that's expected.)
- [ ] **Step 5:** Commit "Add ProfileStore: profiles on disk, migration, CLI token".

### Task 2: OpenRequest URL format

**Files:**
- Create: `Sources/AaronCore/OpenRequest.swift`
- Test: `Tests/AaronCoreTests/OpenRequestTests.swift`

**Interfaces:**
- Produces: `public struct OpenRequest: Equatable, Sendable { public var token: String; public var profile: String?; public var paths: [String]; public init(token:profile:paths:); public init?(url: URL); public var url: URL }`. Format: `aaron://open?token=T&profile=P&path=/a&path=/b` (percent-encoded with `URLComponents`, `+` and `&` encoded). `init?(url:)` returns nil for another scheme/host, a missing token or no paths.

- [ ] **Step 1: Tests:** `roundTripsAwkwardPaths` with paths `"/tmp/a b/c&d#e%f+g.md"` and `"/tmp/čšž ü.md"`, profile `"Blog 2"`; `rejectsOtherHostsMissingTokenOrPaths`; `decodesScriptStyleEncoding`: `URL(string: "aaron://open?token=t&path=%2Ftmp%2Fa%20b.md")!` → paths `["/tmp/a b.md"]`, profile nil.
- [ ] **Step 2:** run, fails (missing type). **Step 3:** implement. **Step 4:** `swift test --filter OpenRequestTests` passes.
- [ ] **Step 5:** Commit "Add OpenRequest for aaron://open URLs".

### Task 3: AppModel holds profiles

**Files:**
- Modify: `App/Sources/Aaron/AppModel.swift`, `App/Sources/Aaron/AaronApp.swift`, `App/project.yml` (scheme env `AARON_SUPPORT_DIR: $(BUILD_DIR)/test-host-support`; Debug/Release bundle id, `CFBundleDisplayName`, Info.plist key `AaronSupportFolderName` = `$(AARON_SUPPORT_FOLDER)` with build setting `Aaron Debug`/`Aaron` per configuration)
- Test: rewrite `App/Tests/AppModelTests.swift`

**Interfaces:**
- Consumes: `ProfileStore` (Task 1).
- Produces on `AppModel`:
  - `init(store: ProfileStore)`; `static func makeDefault() -> AppModel` (reads `AaronSupportFolderName` from `Bundle.main`, env override)
  - `private(set) var profileNames: [String]`, `private(set) var defaultProfileName: String`
  - `func configuration(for name: String) -> Configuration` (unknown name → default profile's)
  - `func setConfiguration(_ c: Configuration, for name: String)` (debounced 400 ms save per profile; notifies windows using `name` via `configurationChanged(from:)`)
  - `var settingsProfileName: String`; `var settingsConfiguration: Configuration { get set }` (get/set through the two above, for Settings bindings)
  - `func addProfile(copying name: String) throws -> String` (name "<name> copy", "<name> copy 2", …)
  - `func renameProfile(_ old: String, to new: String) throws`, `func deleteProfile(_ name: String) throws`, `func setDefaultProfile(_ name: String) throws`, `func importProfile(from url: URL, named: String) throws`
  - `func reloadProfiles()`, `func revealProfilesFolder()`, `func saveIfPending()`
  - `var configurationError: String?` (messages name the profile)
  - `func register(_ window: DocumentWindowModel)` (weak); `var windows: [DocumentWindowModel]` (live ones)
  - `var frontProfileName: String?` (set by the key document window, Task 4)
- Unreadable profiles: kept in a `Set<String>`, never saved until reloaded successfully; their in-memory config is `.default`.

- [ ] **Step 1: Tests** (temp `ProfileStore` per test; port the five existing tests to profiles): `missingFolderMigratesAndSavesChanges`, `unreadableProfileIsReportedAndNeverOverwritten` (other profile still saves), `reloadAfterFixingResumesSaving`, `pendingChangesSavedOnQuit`, `reloadDoesNotRewrite`, plus `renamingDefaultKeepsItDefault`, `deletingProfileMovesItsWindowsToDefault` (needs a registered `DocumentWindowModel`; write after Task 4 if simpler — keep in this file), `addProfileCopiesAndNamesUniquely` (`"Default copy"`, then `"Default copy 2"`), `invalidRenameThrowsAndChangesNothing`.
- [ ] **Step 2:** run hosted tests (`cd App && xcodegen generate -q && xcodebuild ... test -only-testing:AaronTests`) → compile failure.
- [ ] **Step 3:** Implement. Make `AaronApp` use an `NSApplicationDelegateAdaptor(AppDelegate.self)` whose `appModel = AppModel.makeDefault()`; pass it into scenes. Settings, commands and windows still compile by using `settingsConfiguration` (Settings) and `configuration(for:)` (others) — adjust call sites minimally; full UI comes in Task 7/8.
- [ ] **Step 4:** hosted tests pass; `scripts/smoke-test.sh` after updating it to write `$work/support/Profiles/Default.json` and export `AARON_SUPPORT_DIR` (scenario-specific extra profiles: every `*.json` in `App/SmokeTests/<name>.profiles/`, with `$FIXTURES` substituted) → all PASS.
- [ ] **Step 5:** Commit "Keep configuration as profiles in AppModel".

### Task 4: Window profile

**Files:**
- Modify: `App/Sources/Aaron/DocumentWindowModel.swift`, `App/Sources/Aaron/DocumentWindow.swift` (drop `.onChange(of: appModel.configuration)`; register model; set `appModel.frontProfileName` when `appearsActive` becomes true), `App/Sources/Aaron/EditorView.swift` call site (`settings: model.configuration.editor`), `App/Sources/Aaron/HelpView.swift` (`HelpRequest.profileName: String`; `configuration(for:)`), `App/Sources/Aaron/AppCommands.swift` (Review menu uses `window?.configuration ?? appModel.configuration(for: appModel.defaultProfileName)`; New Pelican Post uses the default profile's template)
- Test: `App/Tests/DocumentWindowModelTests.swift`

**Interfaces:**
- Produces on `DocumentWindowModel`: `init(appModel:profileName:)` (defaults to `appModel.defaultProfileName`); `var profileName: String` (didSet → `configurationChanged(from:)` with the old profile's config); `func profileRenamed(to:)` (no reconfiguration); `var configuration: Configuration { appModel.configuration(for: profileName) }`.

- [ ] **Step 1: Tests:** `switchingProfileChangesRendererAndDetection` (profile A: detection automatic, default pelican renderer `external`; profile B: detection `.never`; Pelican text; switch A→B → `isPelican == false`, `rendererID == builtinID`); `switchingKeepsSuggestions` (session with one open suggestion survives a switch); `editingOtherProfileDoesNotTouchWindow` (window on A, `setConfiguration` for B changing renderer list → `rendererID` unchanged); `editingOwnProfileRefreshesWindow` (remove the window's renderer from its profile → falls back to builtin).
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** hosted tests + smoke tests pass.
- [ ] **Step 5:** Commit "Per-window profiles".

### Task 5: Opening files from requests

**Files:**
- Modify: `App/Sources/Aaron/AppModel.swift` (or new `App/Sources/Aaron/OpenRequestHandler.swift`), `App/Sources/Aaron/AaronApp.swift` (AppDelegate installs `kInternetEventClass/kAEGetURL` handler in `applicationWillFinishLaunching`), `App/project.yml` (`CFBundleURLTypes` with scheme `aaron`)
- Test: `App/Tests/OpenRequestHandlingTests.swift`

**Interfaces:**
- Consumes: `OpenRequest`, `ProfileStore.cliToken()`.
- Produces: `AppModel.handle(_ url: URL)`; `AppModel.pendingProfile(for fileURL: URL) -> String?` (consumed once by `DocumentWindow` when creating its model); an injectable `var openDocument: (URL) -> Void` defaulting to `NSDocumentController.shared.openDocument(withContentsOf:display:true)`.
- Behaviour: wrong/missing token → ignore, `Logger` warning, no open. Unknown profile (case-insensitive lookup) → `configurationError` naming it, open with default. File already open in a registered window (compare standardized file URLs) → set that window's `profileName` (if given) and still call `openDocument` (brings it to front). Otherwise store pending profile, call `openDocument`.

- [ ] **Step 1: Tests** (inject `openDocument` recorder): `wrongTokenOpensNothing`; `opensEachPathWithPendingProfile` (`pendingProfile(for:)` returns `"Blog"` once, then nil); `profileMatchingIgnoresCase` (`"blog"` → `"Blog"`); `alreadyOpenFileSwitchesItsWindow` (registered window with that `fileURL` on Default → `"Blog"`, and `openDocument` still called once).
- [ ] **Step 2:** fail. **Step 3:** implement; `DocumentWindow` passes `appModel.pendingProfile(for:)` into `DocumentWindowModel.init`. **Step 4:** pass.
- [ ] **Step 5:** Commit "Open files from aaron:// requests".

### Task 6: The `aaron` script

**Files:**
- Create: `App/Sources/Aaron/Resources/aaron` (zsh, executable; copied to `Contents/Resources/aaron`; add a postbuild `chmod +x` only if the copy loses the bit)
- Test: `Tests/AaronCoreTests/CommandScriptTests.swift` (runs the script from the source tree via `#filePath` with `AARON_SUPPORT_DIR` temp folder and `AARON_CLI_DRY_RUN=1`)

**Behaviour (exact):**
- `aaron --help` / no args → usage on stdout (no args: on stderr, exit 2).
- `aaron --list-profiles` → one name per line, the default followed by ` (default)`.
- `aaron [--profile NAME] FILE...` → resolve each FILE to an absolute path; any missing → `aaron: no such file: FILE` on stderr, exit 1, nothing opened. Unknown profile → `aaron: unknown profile "NAME". Profiles: A, B` on stderr, exit 1. Profile matched case-insensitively, canonical name sent.
- App = `${0:A:h:h:h}` (works through the symlink). Support folder = `$AARON_SUPPORT_DIR` or `~/Library/Application Support/$(defaults read "$APP/Contents/Info" AaronSupportFolderName)`.
- No `cli-token` yet → `open -g -a "$APP"` and wait up to 15 s for it (then error, exit 1).
- Sends `open -a "$APP" "aaron://open?token=…&profile=…&path=…"` (percent-encode every byte outside `A-Za-z0-9-._~/`, `LC_ALL=C`). `AARON_CLI_DRY_RUN=1` prints that URL instead of running `open`.

- [ ] **Step 1: Tests:** `listsProfilesMarkingDefault`; `missingFileFailsAndOpensNothing` (exit 1, stdout empty); `unknownProfileListsAvailable`; `printsDecodableURL` — dry-run output parsed with `OpenRequest(url:)` equals token from `ProfileStore.cliToken()`, profile `"Blog"` for `--profile blog`, paths absolute incl. `"a b&c#%ü.md"` created in temp dir and passed relatively (run with that temp dir as cwd).
- [ ] **Step 2:** fail (script missing). **Step 3:** write script. **Step 4:** `swift test --filter CommandScriptTests` passes.
- [ ] **Step 5:** Commit "Add the aaron command-line script".

### Task 7: Window UI for switching

**Files:**
- Modify: `App/Sources/Aaron/DocumentWindow.swift` (toolbar `ProfileMenu` with identifier `profileMenu`; status bar profile name as a borderless `Menu`, identifier `statusProfile`), `App/Sources/Aaron/AppCommands.swift` (`View ▸ Profile` submenu with a checkmark `Toggle`/`Picker` per profile)
- Test: `App/UITests/ProfileUITests.swift`; extend `AaronUITestCase.launch(... profiles: [String: [String: Any]] = [:], defaultProfile: String? = nil)` to write `support/Profiles/*.json` and `profiles.json` and set `AARON_SUPPORT_DIR` (replace `AARON_CONFIG_PATH`).

- [ ] **Step 1: UI test** `testSwitchingProfileChangesRendererMenu`: profiles Default (fake external renderer) and `Plain` (no renderers, detection never); open Pelican fixture; status shows `Default` and `Pelican`; choose View ▸ Profile ▸ Plain → status shows `Plain` and `Markdown`, renderer popup has only *Markdown (built-in)*.
- [ ] **Step 2:** run (ask the user first; UI automation needs their approval) → fails. **Step 3:** implement. **Step 4:** passes.
- [ ] **Step 5:** Commit "Profile menu in windows".

### Task 8: Settings: Profiles tab and profile picker

**Files:**
- Modify: `App/Sources/Aaron/SettingsView.swift` (new first tab `ProfilesSettings`; a `Picker("Profile", selection: $appModel.settingsProfileName)` header on the General/Preview/AI/Pelican tabs, identifier `settingsProfile`; all `$appModel.configuration` → `$appModel.settingsConfiguration`; General tab's file section shows the profile file path; Restore Defaults resets the selected profile; Reload from Disk → `reloadProfiles()`; on appear, `settingsProfileName = appModel.frontProfileName ?? defaultProfileName`)
- Profiles tab: list (identifier `profileList`, default marked "Default" badge), buttons Add (`addProfile`), Rename (inline text field, error shown under it), Delete… (confirmation; disabled for default/last), Set as Default, Import… (`NSOpenPanel` for JSON, then name prompt prefilled with the file's base name), Show in Finder.
- Test: extend `App/UITests/SettingsUITests.swift`

- [ ] **Step 1: UI tests:** `testAddRenameAndSetDefaultProfile` (Add → "Default copy" appears; rename to "Blog"; Set as Default; reopen Settings → `profiles.json` in the support dir names Blog); `testSettingsEditSelectedProfileOnly` (select Blog in picker, change font size → `Profiles/Blog.json` has it, `Default.json` doesn't).
- [ ] **Step 2–4:** fail, implement, pass. Existing `testAddingAnActionShowsItInTheReviewMenuAndSavesConfig` must read `Profiles/Default.json` now.
- [ ] **Step 5:** Commit "Profiles in Settings".

### Task 9: Installing the command and the app

**Files:**
- Create: `Sources/AaronCore/CommandLineInstaller.swift`, `Tests/AaronCoreTests/CommandLineInstallerTests.swift`, `scripts/install.sh`
- Modify: `App/Sources/Aaron/AppCommands.swift` (`CommandGroup(after: .appSettings) { Button("Install Command Line Tool…") }` → installs to `~/.local/bin`, then checks login-shell PATH via `ProcessRunner().run("print -r -- $PATH", …)`, shows an `NSAlert` with the outcome and, if needed, `export PATH="$HOME/.local/bin:$PATH"` for `~/.zprofile`)
- Smoke: `App/SmokeTests/cli.json` + harness step `cli: [String]` (runs `Bundle.main` `aaron` script with the given args, `$WORK` substituted) and expectation `windowProfiles: [String: String]` (file name → profile)

**Interfaces:**
- `public enum CommandLineInstaller { public static func install(script: URL, into binDirectory: URL) throws -> URL; public static func directory(_ dir: URL, isIn pathVariable: String) -> Bool }`; `public enum InstallError: LocalizedError { case existingFile(URL) }`. Existing symlink replaced; regular file → `existingFile`; creates the directory.

- [ ] **Step 1: Tests:** `createsDirectoryAndSymlink`, `replacesExistingSymlink`, `refusesRegularFile` (file content unchanged), `pathCheckHandlesTildeAndTrailingSlash` (`"/usr/bin:/Users/x/.local/bin/"` contains `/Users/x/.local/bin`).
- [ ] **Step 2–4:** fail, implement, pass.
- [ ] **Step 5: Smoke scenario `cli`:** second document copied into the work dir, extra profile `Plain`; step `cli: ["--profile", "plain", "$WORK/second.md"]`, wait 3, expect `windowCount: 2`, `windowProfiles: {"second.md": "Plain", "story.md": "Default"}`; then `cli: ["--profile", "Plain", "$WORK/story.md"]` → `windowProfiles: {"story.md": "Plain"}`, `windowCount: 2`. Run `scripts/smoke-test.sh cli` → PASS.
- [ ] **Step 6:** `scripts/install.sh`: Release build into `build/Release`, if `osascript -e 'application id "net.gaivo.Aaron" is running'` is true ask `Quit Aaron and replace it? [y/N]` and quit it via `osascript`, then `ditto` to `/Applications/Aaron.app`. Run `bash -n`/`zsh -n` on it; actual install only with the user's go-ahead.
- [ ] **Step 7:** Commit "Install the aaron command and the app".

### Task 10: Documentation and verification

**Files:**
- Create: `docs/user/profiles.md`, `docs/user/command-line.md`
- Modify: `docs/user/README.md`, `settings.md` (profiles, `AARON_SUPPORT_DIR` instead of `AARON_CONFIG_PATH`), `getting-started.md` (install app + command), `example-blog-setup.md` (import as profile *Blog*; draft script example `aaron --profile Blog "$file"`), `markdown-help.md` (help follows the window's profile), `pelican.md` (New Pelican Post uses the default profile), `docs/developer/design.md`, `testing.md` (`AARON_SUPPORT_DIR`, harness `cli`/`windowProfiles`/profile folders), `development.md`, `verification-status.md`, `docs/decisions.md` (one entry per *(Claude's call)*: migration rename, Settings opens on front window's profile, status bar always shows profile, New Pelican Post uses default, check all files before opening, case-insensitive names, already-open file switches, separate Debug identity, token, `AARON_SUPPORT_DIR` replaces `AARON_CONFIG_PATH`, name rules)
- [ ] **Step 1:** write docs; `git grep -n AARON_CONFIG_PATH` returns nothing; no references to the author's site or tools remain.
- [ ] **Step 2:** full verification: `swift test` (no warnings), hosted + UI tests (with the user's approval), `scripts/smoke-test.sh`, Release build.
- [ ] **Step 3:** Commit "Document profiles and the aaron command".
