# Verification status (first version)

State at the end of the first development session (2026-10-24). macOS UI
automation was not available, and the screen was locked for most of the
session, so some checks are still outstanding.

## Verified

| Area | How |
|---|---|
| All package logic | `swift test`: 192 tests, no warnings |
| App logic (configuration saving, window model) | `AaronTests`: 12 hosted tests |
| Preview: built-in, external, renderer switching, errors, JavaScript blocking | smoke tests |
| Review: run, read-only while running, accept, undo, dismiss, stale suggestions, failures, cancel | smoke tests |
| Pelican: detection, tag loading, completion candidates, auto-completion trigger | smoke tests |
| Real tools: a real Pelican blog's preview, full-build and tag scripts, theme assets | harness runs with a profile like `docs/user/examples/pelican-blog.json` |
| Real AI: Claude and Codex return suggestions that resolve correctly | live tests, plus a Claude run on a 1,374-word post in the app (27 suggestions, all located) |
| Light and dark mode: metadata key colours, review panel selection, built-in and external previews | harness snapshots with `AARON_APPEARANCE` (2026-10-24); see below for what snapshots can't show |
| Profiles: storage, migration, naming, unreadable files, default, rename/delete/import | `ProfileStoreTests`, `AppModelTests` |
| Per-window profiles: switching, following edits/renames/deletes, request handling | `DocumentWindowModelTests`, `OpenRequestHandlingTests`, smoke `profiles` |
| `aaron` command: arguments, errors, URL encoding; end to end against the running app | `CommandScriptTests`, smoke `cli` |
| Release build compiles without the harness | `xcodebuild -configuration Release` |
| Menu commands enabled for the active document window | checked by hand (View ▸ Show/Hide Preview, Review actions and Clear Suggestions) |
| UI: opening, typing, preview toggling and renderer switching, review run/accept/undo/dismiss/keyboard navigation, read-only while running and cancel (⌘.), AI errors, Pelican detection and tags, tag completion popup (opens while typing, Return accepts), New Pelican Post, adding an action in Settings | `AaronUITests`: 20 tests pass (2026-10-25), including reverting/reopening suggestions, Markdown Help (shortcut and Help menu, plain and Pelican with plugins), switching profiles from View ▸ Profile and the status bar, and adding, renaming, defaulting and editing profiles in Settings. Runtime warning from AppKit, see [testing.md](testing.md#known-warning-priority-inversion-in-ui-tests) |

## Not yet verified

Still to check by hand:

- that `aaron` started without Aaron running shows the window (the command
  succeeded both with and without an existing token, 2026-10-25; the window
  itself was not observed by a test);
- Aaron ▸ Install Command Line Tool… and `scripts/install.sh`;
- Esc on an empty tag listing all tags;
- the Settings window beyond adding an action (Test Command, Restore
  Defaults, renderer and provider editing, the new Markdown Help fields);
- the review panel's open/close animation;
- the review panel in dark mode on screen: in harness snapshots its text
  outside the selected card looks dim and its buttons white, probably
  because snapshots can't draw translucent backgrounds;
- File ▸ Revert with open suggestions.
