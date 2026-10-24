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
| Real tools: `scripts/render-post`, `scripts/build-post`, `scripts/list-tags`, theme assets | harness runs with `docs/user/examples/pelican-blog.json` |
| Real AI: Claude and Codex return suggestions that resolve correctly | live tests, plus a Claude run on a 1,374-word post in the app (27 suggestions, all located) |
| Release build compiles without the harness | `xcodebuild -configuration Release` |
| Menu commands enabled for the active document window | checked by hand (View ▸ Show/Hide Preview, Review actions and Clear Suggestions) |
| UI: opening, typing, preview toggling and renderer switching, review run/accept/undo/dismiss/keyboard navigation, read-only while running and cancel (⌘.), AI errors, Pelican detection and tags, tag completion popup (opens while typing, Return accepts), New Pelican Post, adding an action in Settings | `AaronUITests`: 16 tests pass, including reverting/reopening suggestions and Markdown Help (shortcut and Help menu, plain and Pelican with plugins). Runtime warning from AppKit, see [testing.md](testing.md#known-warning-priority-inversion-in-ui-tests) |

## Not yet verified

Changed after the last runs that put windows on screen, so far only built and
unit tested:

- the harness no longer activating the app (smoke tests not rerun);
- the dark blue metadata key colour, seen only in code (a snapshot attempt
  was spoiled by a stray keystroke);
- the review panel in dark mode.

Still to check by hand:

- Esc on an empty tag listing all tags;
- the Settings window beyond adding an action (Test Command, Restore
  Defaults, renderer and provider editing, the new Markdown Help fields);
- the review panel's open/close animation;
- dark mode in general;
- File ▸ Revert with open suggestions.
