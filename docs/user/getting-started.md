# Getting started

## Installing

Aaron is built from source (see the [developer guide](../developer/development.md)).
From the repository:

```sh
scripts/install.sh
```

This builds the app and installs it as `/Applications/Aaron.app`. An older
copy is moved to the Trash; if Aaron is running, the script asks before
quitting it. To open files from Terminal or your own scripts, then choose
**Aaron ▸ Install Command Line Tool…** (see [The `aaron` command](command-line.md)).

The app is signed locally ("ad hoc"), so the first time you open it you may
need to Control-click it in Finder and choose **Open**.

AI features use command-line tools you already have and are logged in to:
[Claude Code](https://claude.com/claude-code) (`claude`) and/or
[OpenAI Codex](https://developers.openai.com/codex) (`codex`). Aaron never
asks for an API key; it uses your existing subscriptions through these tools.

## Opening and creating documents

Aaron edits Markdown (`.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`) and plain
text files.

- **File ▸ New** (⌘N) opens an empty document.
- **File ▸ New Pelican Post** (⌥⌘N) opens a new document pre-filled with your
  Pelican metadata template (see [Pelican support](pelican.md)).
- **File ▸ Open…** (⌘O), dragging files onto the app icon, or **Open With ▸
  Aaron** in Finder open existing files.

Documents are saved as UTF-8. Aaron uses the standard macOS document system:
autosave, **File ▸ Revert To**, version browsing, recent documents and window
restoration all work as in other Mac apps. Files in other encodings are read
as Latin-1 if they are not valid UTF-8, and saved as UTF-8.

## The window

![Window layout](images/window.png)

A document window has up to three parts:

1. **The editor** on the left. Toggle it with the **Editor** toolbar button
   or **View ▸ Show/Hide Editor** (⌥⌘E).
2. **The preview** in the middle (or on the right when review is closed).
   Toggle it with the **Preview** toolbar button or **View ▸ Show/Hide
   Preview** (⌥⌘P). Drag the divider to resize it.
3. **The review panel** on the right, for AI suggestions. Toggle it with the
   **Review** toolbar button or **View ▸ Show/Hide Review** (⌥⌘R).

The editor and the preview can't both be hidden. Which parts a window shows
when it opens is set per profile; see
[Profiles](profiles.md#panes-shown-when-a-file-opens).

The toolbar's **AI Actions** menu (sparkles icon) runs an AI action and opens
the review panel. The status bar at the bottom shows word and character
counts, whether the document is treated as Markdown or as a Pelican post,
and the window's [profile](profiles.md), which you can change there.

New windows open at 1400 × 860 points; macOS remembers the size you choose.
