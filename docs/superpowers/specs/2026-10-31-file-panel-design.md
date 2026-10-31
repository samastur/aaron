# File panel

Design agreed with the user on 2026-10-31. Items marked *(Claude's call)*
were decided while writing this down and can be changed.

## Why

The user keeps Markdown in a few places: blog posts in the blog's folder,
documentation they wrote, notes. Today every file has to be found through
**File ▸ Open…** or Finder, and nothing ties a profile to the part of the
file system it is about. The user wants each profile to have its own
**root folder** and a panel listing the Markdown files under it, so the
*Blog* profile shows only blog posts without being pointed at the right
folder each time.

This builds on per-profile panes (commit c57b6e8), which was done as a
stepping stone for it.

## Goals

- A **file panel** on the left of the window, left of the editor, preview
  and review panes.
- Each profile has a **root folder**, the user's home folder by default.
  The panel shows the tree under it.
- The tree lists **only Markdown files** and **only folders that lead to
  one**: a folder without Markdown files is hidden unless a folder below it
  has some.
- Which files count as Markdown is decided by **file extension**,
  configurable per profile.
- A **filter** field at the top of the panel finds files quickly by name.
- Clicking a file **loads it in the current window**. ⌘-click or a middle
  click opens it **in a new window**.
- The root is **easy to change** both in Settings and from the panel.
- Whether the panel is shown is part of the profile's panes.

## Non-goals

- Matching the filter against folder names or the path. The user first
  asked for "any part of the path below the root", then decided name
  matching is enough when the search is limited to the root.
- Our own folder walker or an external tool (`find`, `fd`). Spotlight is
  used for now; a walker may be added later as a fallback.
- File operations in the panel: creating, renaming, moving, deleting.
- Listing files that are not Markdown.
- Several roots per profile.

## Anti-goals

- **Making the user wait for a scan**, or freezing the window while one
  runs. A home folder must be usable as a root.
- **Losing edits or review work** when a click replaces the window's
  document without asking. The user: "Always get confirmation if data would
  be lost."
- **Changing what existing profiles look like in an unexpected way**,
  other than gaining the panel (see *Panes*).

## How it gets made

These were decided with the user:

- **Spotlight** finds the files: one query per root, limited to the root
  (`NSMetadataQuery` with the root as its search scope, or the equivalent
  `MDQuery` API), for files whose name ends in one of the profile's
  extensions. The query stays live while a window shows the panel, so
  files added, renamed or removed under the root appear and disappear on
  their own.
- **One mode.** An earlier idea had two modes (browse every folder, or
  only folders leading to Markdown). The user agreed one mode is enough
  since Spotlight is fast: the tree is always built from the query's
  results.
- **Fallback:** when Spotlight doesn't index the root at all (for example
  an unindexed drive), the panel falls back to plain folder browsing:
  every non-hidden folder is shown, its contents read when it is expanded,
  and only Markdown files are listed. This keeps the panel from being
  empty in places Spotlight doesn't reach. *(Claude's call, from here to
  the end of this item:)*
  - "Not indexed" is detected by a query for *any* item under the root
    returning nothing. An indexed root that simply has no Markdown files
    shows "No Markdown files here" instead, not the fallback.
  - In fallback mode the filter field is disabled, with the note "Search
    needs Spotlight, which doesn't index this folder." Nothing is watched
    for changes; a folder is read again each time it is expanded.
  - The panel decides once per query start (window opened, root or
    extensions changed); it doesn't switch modes on its own later.
- **Known limit, accepted by the user:** Spotlight does not index hidden
  folders, unindexed drives or folders excluded in System Settings ▸
  Spotlight. Files there don't appear in the tree or the filter (outside
  the fallback above).
- macOS asks once for permission the first time Aaron reads Desktop,
  Documents or Downloads. That is expected and needs no handling beyond
  the panel not breaking if access is denied.

## The panel

```
┌──────────────────┬──────────────┬──────────────┬─────────┐
│ ⌂ blog       ▾   │              │              │         │
│ [ Filter      ]  │   editor     │   preview    │ review  │
│ ▾ content        │              │              │         │
│   ▾ 2026         │              │              │         │
│     • first.md   │              │              │         │
│     • second.md  │              │              │         │
│ ▸ drafts         │              │              │         │
└──────────────────┴──────────────┴──────────────┴─────────┘
```

From top to bottom:

1. **Header**: the root folder's name (the full path as tooltip). Clicking
   it opens a menu with **Choose Root Folder…** (a folder picker) and
   **Use Home Folder**.
2. **Filter** field.
3. **Tree**: folders with disclosure triangles, then Markdown files.
   Folders first, then files, each sorted by name the way Finder does
   (`localizedStandardCompare`) *(Claude's call)*. Hidden files and
   folders never appear: names starting with `.` and anything macOS marks
   as hidden (`URLResourceValues.isHidden`), which removes `~/Library`
   from a home-folder root (agreed with the user).
4. **iCloud Drive** (agreed with the user): when the iCloud Drive folder
   (`~/Library/Mobile Documents/com~apple~CloudDocs`) is under the root, so
   the hidden-folder rule would otherwise hide it, it appears as its own
   **iCloud Drive** entry at the top of the tree, holding the Markdown
   files found there. When the root is inside iCloud Drive, it is an
   ordinary folder.

Further behaviour:

- **Right-click a folder**: **Use as Root**, **Show in Finder**.
  Right-click a file: **Open in New Window**, **Show in Finder**
  *(Claude's call for everything but Use as Root)*.
- **Current file**: the window's document is selected in the tree, and its
  folders are expanded to reveal it. Untitled documents and files outside
  the root have nothing selected.
- **While Spotlight's first results are still coming in**, the panel shows
  a small progress indicator; the tree fills in as results arrive *(Claude's
  call)*.
- **Ignored folders**: folders with these names, at any depth, are left out
  together with everything below them. Default: `node_modules`, because a
  home folder with code projects otherwise lists thousands of dependency
  `README.md` files *(Claude's call, the user did not object)*.

## The filter

- Typing shows a **flat list** of the Markdown files under the root whose
  **file name** contains the text, ignoring case and diacritics. Each row
  shows the name and, under it, the folder path relative to the root
  *(Claude's call)*.
- The same click rules apply as in the tree. ↓ moves into the list and
  Return opens the selected file *(Claude's call)*.
- Clearing the field (or Esc) brings the tree back.
- The filter matches against the files Spotlight has already found, so it
  is instant and needs no new query *(Claude's call: one query serves both
  the tree and the filter)*. It is disabled in fallback mode (see above).

## Opening files

- **Click** a file: it replaces the document in the current window.
  SwiftUI's document windows hold one document each, so in practice the
  file opens as a new document window **at the current window's position
  and size**, and the current window closes. Aaron autosaves, so the old
  document's edits are kept; if closing would ask a question (for example
  an untitled document with text), the normal close dialog appears and
  cancelling it keeps both windows *(Claude's call)*.
- **Review work would be lost** when the window has suggestions that are
  not yet accepted or dismissed, or an AI action is running. The click
  then first asks *(the user wants a confirmation; the wording and buttons
  are Claude's call)*:

  > Open “second.md” in this window?
  > The 3 open suggestions for “first.md” will be lost. (or: The running
  > “Grammar and spelling” action will be cancelled.)
  >
  > **Open in New Window** · **Replace** · **Cancel**

  **Open in New Window** is the default button, so Return keeps the
  review. ⌘-click never asks, since nothing is lost.
- **Window tabs and full screen** *(Claude's call)*: in a tab group, the
  new window takes the old tab's place. In full screen, the swap may
  visibly move through a new Space; that is accepted as a known rough edge
  rather than replacing SwiftUI's document handling. If the builder finds
  a clean way to swap the document inside the same window, that is better
  and allowed.
- The window that takes over keeps the window's **profile**, **panes** and
  the panel's **expanded folders and filter text**, so the switch looks
  like one window changing its document.
- **⌘-click, middle click, or Open in New Window**: opens the file in a
  new window with the same profile. Panes come from the profile, as for
  any newly opened file.
- If the clicked file is **already open** in another window, that window
  comes to the front instead and nothing closes.
- Clicking the file the window already shows does nothing.

## Changing the root

- **Settings ▸ General ▸ Files** (new section): **Root folder** (path field
  with **Choose…**, empty or `~` meaning the home folder), **Extensions**
  (comma-separated, default `md, markdown`) and **Ignored folders**
  (comma-separated, default `node_modules`). Default extension list
  including `markdown` is *(Claude's call)*.
- **From the panel** (header menu, **Use as Root**): changes the
  **profile's** root setting, exactly as editing it in Settings would.
  Every window using that profile follows.
- Changing the root, extensions or ignored folders restarts the query in
  every window using the profile.

## Panes

- The panel becomes a fourth pane: `panes.files` in the profile, a
  **Files** switch in **Settings ▸ General ▸ Panes**, a toolbar button and
  **View ▸ Show/Hide Files** (⌃⌘S, the usual Mac shortcut for a sidebar).
- **On by default**, also for existing profiles that don't mention it
  *(Claude's call)*.
- It doesn't count for the rule that the editor and the preview are never
  both hidden.
- It is shown and hidden by profile switches exactly like the other panes.
- *(Left to the builder:)* whether it is a SwiftUI sidebar
  (`NavigationSplitView`) or another pane in the existing split view, as
  long as it sits leftmost, can be resized, and the window stays usable at
  the current minimum widths.

## Configuration

New keys in the profile file, all optional:

```json
{
  "panes": { "files": true },
  "files": {
    "root": "~",
    "extensions": ["md", "markdown"],
    "ignoredFolders": ["node_modules"]
  }
}
```

Extensions are matched case-insensitively, without the dot; a leading dot
typed by the user is accepted and dropped. An empty extension list means
the defaults *(Claude's call)*. A root that doesn't exist or isn't a folder
shows a message in the panel ("Folder not found") with the header menu
still usable.

## Testing

- Unit tests for everything that doesn't need Spotlight: building the tree
  from a list of file paths (pruning, ignored folders, hidden names,
  sorting), filtering, configuration decoding, extension normalisation.
  The Spotlight part sits behind a small protocol so tests feed it paths.
- A smoke-test scenario that opens a window on a temporary folder and
  checks the tree and a click that loads another file. Spotlight may not
  index temporary folders quickly (or at all), so the smoke test is
  expected to exercise the fallback, or to use a fake file source in the
  Debug harness *(left to the builder)*.
- User guide: a new page for the file panel, plus updates to the profiles,
  settings, getting started and keyboard shortcuts pages.

## Left to the builder

- Sidebar implementation (see *Panes*).
- How expanded folders and filter text are handed to the window that
  takes over after a click (the existing `pendingProfiles` hand-off for
  the `aaron` command is a likely model).
- How results from the live query are batched so a home-folder root
  doesn't redraw the tree for every file found.
