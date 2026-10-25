# Testing

## Package unit tests

```sh
swift test
```

Swift Testing suites in `Tests/<Module>Tests`. They cover all logic in the
package: quote resolution and the review session state, response parsing,
prompt building, command templates and the process runner (real `zsh`
processes, including timeouts, cancellation and large I/O), front matter,
highlighting, statistics, configuration, the renderers and asset resolver,
Pelican detection, tag parsing and completion.

### Live AI tests

`Tests/AaronAITests/LiveProviderTests.swift` sends a short document with a
grammar mistake to the default Claude and Codex providers and checks that
the suggestion lands on the right text. They are skipped unless enabled:

```sh
AARON_LIVE_AI=1 swift test --filter LiveProviderTests
```

## App unit tests

```sh
cd App
xcodebuild -project Aaron.xcodeproj -scheme Aaron -derivedDataPath ../build/DerivedData \
  test -only-testing:AaronTests
```

XCTest cases in `App/Tests`, hosted in the app, for logic that lives in the
app target (`AppModel` configuration handling, `DocumentWindowModel`). They
need no special permissions. The test scheme sets `AARON_SUPPORT_DIR` so the
host app never touches the real profiles.

## Smoke tests

```sh
scripts/smoke-test.sh                 # build, then run all scenarios
SKIP_BUILD=1 scripts/smoke-test.sh review stale   # selected scenarios
```

End-to-end checks of the real app that need **no** macOS automation
permission: Debug builds contain a harness (`DebugHarness.swift`) that drives
the first document window from a JSON step script and checks expectations
from inside the app. Each scenario `App/SmokeTests/<name>.json` runs with
`App/SmokeTests/config.json` as the profile *Default* (fake AI providers,
renderers and tag command from `App/UITests/Fixtures`) on `<name>.md`, or
`story.md` if there is none. Extra profiles for a scenario go in
`App/SmokeTests/<name>.profiles/`, extra files for its work folder in
`App/SmokeTests/<name>.files/`.
The script prints `PASS`/`FAIL` per scenario and keeps the output folder of
failed ones.

### Harness reference

Run the Debug app with:

| Variable | Meaning |
|---|---|
| `AARON_DEBUG_SCRIPT` | path of the step script (JSON array) |
| `AARON_SNAPSHOT_DIR` | where snapshots, `progress.txt` and `result.txt` go |
| `AARON_SUPPORT_DIR` | settings folder (profiles) to use |
| `WORK` | the scenario's work folder, for `$WORK` in `cli` steps |
| `AARON_APPEARANCE` | `dark` or `light` forces that appearance; otherwise the system's |

Within a step, actions run first (in the order listed), then `wait`,
`waitIdle`, `expect`, `snapshot` and finally `quit`.

| Action | Effect |
|---|---|
| `"caretAfter": "text"` | put the caret after the first occurrence |
| `"caretAtEnd": true` | put the caret at the end |
| `"type": "text"` | type character by character (auto-completion is counted, its popup suppressed) |
| `"complete": true` | invoke completion (opens the modal popup; avoid in unattended runs) |
| `"review": true/false` | show/hide the review panel (without animation) |
| `"run": "actionID"` | run an AI action |
| `"cancel": true` | cancel the running action |
| `"accept": n`, `"dismiss": n` | accept/dismiss the n-th highlighted suggestion |
| `"undo": true` | undo |
| `"renderer": "id"` | switch preview renderer |
| `"profile": "name"` | switch the window's profile |
| `"cli": ["--profile", "x", "$WORK/a.md"]` | run the bundled `aaron` command (opens in the background, `AARON_OPEN_IN_BACKGROUND`); a nonzero exit is a failure |
| `"preview": true/false` | show/hide the preview |
| `"wait": seconds` | sleep |
| `"waitIdle": true` | wait until no AI action runs and no preview is pending |
| `"snapshot": "name"` | write `name-window.png`, `name-preview.png`, `name-state.json`, view and controller dumps |
| `"expect": {…}` | record failures for mismatches (below) |
| `"menu": ["Review", "Next Suggestion"]` | choose a main-menu item (fails if missing or disabled) |
| `"quit": true` | write `result.txt` (`PASS`, `FAIL` plus failures, or `SKIP` plus reason) and quit |

Expectation keys: `text`, `textContains`, `textLacks`, `isPelican`,
`isEditable`, `renderer`, `previewContains`, `previewError` (bool),
`aiError` (bool), `aiNotice`, `tagCount`, `tagCandidatesStartWith`,
`autoCompletionRequested`, `statuses` (counts by suggestion status, e.g.
`{"open": 2, "notFound": 1}`), `selectedSuggestion` (original text),
`showReview`, `showPreview`, `windowCount`, `anyWindowTextStartsWith`,
`profile`, `windowProfiles` (document file name → its window's profile),
`menuItemEnabled` (menu path), `words`, `previewTextContains`, `previewTextLacks` (the
rendered page's visible text, read with JavaScript from the app).

Notes:

- Window snapshots use `cacheDisplay`, which cannot capture web views; the
  harness paints the web view's own snapshot into the window image.
- When the screen is locked, windows are occluded and AppKit animations
  don't run; the harness therefore toggles the review panel without
  animation. Nothing else depends on the screen being unlocked.
- Menu commands act on the focused window, which SwiftUI does not
  recognise in harness runs, even when the window is key. The `menu` step
  therefore only works for commands that don't need a window (such as File ▸
  New Pelican Post), and scenarios using it report `SKIP` when the app is not
  active. Window commands are covered by the UI tests.
- The harness never activates the app, so smoke tests don't take keyboard
  focus from other apps. Windows still appear on screen while they run.
- The completion popup runs a modal event loop, which would block the
  script; that's why typing suppresses it.

## UI tests

```sh
cd App
xcodebuild -project Aaron.xcodeproj -scheme Aaron -derivedDataPath ../build/DerivedData \
  test -only-testing:AaronUITests
```

XCUITest cases in `App/UITests` launch the app with a temporary
configuration using the fixture scripts. macOS must allow UI automation:
either approve the authentication prompt on every run, or enable it once with
`sudo automationmodetool enable-automationmode-without-authentication`
(undo with `disable-…`). Without it the runner fails with "Authentication
cancelled". The UI tests click and type through the accessibility layer and
complement the smoke tests: they check the real controls, menus and
shortcuts that the harness bypasses.

### Known warning: priority inversion in UI tests

UI test runs report *"[Internal] Thread running at User-interactive
quality-of-service class waiting on a lower QoS thread…"* for most tests.
It comes from AppKit, not from Aaron. When the test runner inspects the menu
bar through accessibility, AppKit builds **File ▸ Revert To**, and
`-[NSDocument _addRevertItemsToMenu:]` waits on a semaphore while listing the
document's saved versions. The full stack (AppKit, CoreFoundation, run loop;
Aaron appears only as `AaronApp.$main`) was captured from the
`com.apple.runtime-issues` log and symbolicated with `lldb`. The warning does
not appear in the package, app unit or smoke tests.

## Fixtures

`App/UITests/Fixtures` holds shell scripts standing in for external tools:

| Script | Stands in for |
|---|---|
| `fake-ai.sh` | an AI provider: checks the prompt contains the document, answers with three suggestions (a replacement, a comment, an unlocatable quote) |
| `slow-ai.sh` | a provider that takes 30 s (for cancellation) |
| `failing-ai.sh` | a provider that exits with an error |
| `fake-preview.sh` | an external renderer wrapping the input in a marker page |
| `failing-preview.sh` | a renderer that fails |
| `fake-tags.sh` | a tag command printing three tags as JSON |
