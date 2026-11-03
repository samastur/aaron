# Windows and tabs

## Tabs

Aaron's document windows can be tabs of one window, as in Finder or Safari.

- **File ▸ New Tab** (⌘T) opens an empty document in a new tab of the
  window in front. It uses that window's [profile](profiles.md) and the
  panes the profile shows. With no document window open, it opens a new
  window with the default profile.
- **⌘W** closes the tab.
- **⌘1** to **⌘8** choose the first eight tabs, **⌘9** the last one. They
  are also in the **Window** menu.
- Drag a tab to reorder it, or out of the tab bar to make it a window of
  its own. **Window ▸ Merge All Windows** makes all windows tabs of one.

Clicking a file in the [file panel](files.md) of an empty new tab opens it
in that tab. If you've typed something in the tab, Aaron asks whether to
save it first.

Whether File ▸ Open… and other ways of opening a file use a new tab or a
new window follows **System Settings ▸ Desktop & Dock ▸ Prefer tabs when
opening documents**.

## The same file in several windows

A file can be open in several windows or tabs at once, for example to read
one part while writing another. Open it again with **File ▸ Open…**, from
Finder, with the [`aaron` command](command-line.md), or with ⌘-click or
**Open in New Window** in the file panel.

Each copy has its own profile, panes, scroll position and AI review. When
one copy is saved (Aaron saves a few seconds after you stop typing), the
others reload the file. A reload keeps your place, and **Edit ▸ Undo**
undoes it like any edit. It's best to type in one copy only: if two copies
both have changes that aren't saved yet, macOS asks which version to keep
when the second one is saved.

A bar at the top of each copy says the file is also open in another
window. Close it with its **×**; it comes back if the file is opened in yet
another window.

Opening a file in several windows relies on internal parts of macOS that
a macOS update may change. If that happens, Aaron turns the feature off
and says so once: a file then opens in one window only, and opening it
again brings that window to the front. Everything else keeps working; a
newer build of Aaron brings the feature back.

## Reopening windows from last time

When Aaron starts, it reopens the document windows and tabs it had open
when you last quit, each with its file and profile, in the same place.
Untitled documents aren't reopened, so Aaron asks about any that have text
when you quit. Files that no longer exist are skipped.

This happens only when Aaron starts on its own: from the Dock, Launchpad,
Spotlight or Finder, or with `aaron` without arguments. When it starts to
open a file or a profile (double-clicking a document, dropping one on the
Dock icon, or `aaron notes.md`), it opens just that, and quitting that
session doesn't change what the next normal start reopens.

Turn this off with **Reopen windows from last time** in **Settings ▸
Profiles ▸ Startup**. It applies to all profiles.
