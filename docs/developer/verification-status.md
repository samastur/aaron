# Verification status (first version)

State at the end of the first development session (2026-10-24). macOS UI
automation was not available, and the screen was locked for most of the
session, so some checks are still outstanding.

## Verified

| Area | How |
|---|---|
| All package logic | `swift test`: 169 tests, no warnings |
| App logic (configuration saving, window model) | `AaronTests`: 9 hosted tests |
| Preview: built-in, external, renderer switching, errors, JavaScript blocking | smoke tests |
| Review: run, read-only while running, accept, undo, dismiss, stale suggestions, failures, cancel | smoke tests |
| Pelican: detection, tag loading, completion candidates, auto-completion trigger | smoke tests |
| Real tools: `scripts/render-post`, `scripts/build-post`, `scripts/list-tags`, theme assets | harness runs with `docs/user/examples/pelican-blog.json` |
| Real AI: Claude and Codex return suggestions that resolve correctly | live tests, plus a Claude run on a 1,374-word post in the app (27 suggestions, all located) |
| Release build compiles without the harness | `xcodebuild -configuration Release` |
| Menu commands enabled for the active document window | checked by hand (View ▸ Show/Hide Preview, Review actions and Clear Suggestions) |

## Not yet verified (needs an unlocked screen)

- The XCUITest suite (`AaronUITests`): written and compiling, never run.
  Selectors will probably need adjustment on the first run. Needs UI
  automation permission.
- By hand:
  - the tag completion popup: it opens while typing, Return inserts the
    tag, Esc on an empty tag lists all tags;
  - keyboard shortcuts;
  - the Settings window (editing lists, Test Command, Restore Defaults);
  - the review panel's open/close animation;
  - dark mode;
  - File ▸ Revert with open suggestions.
