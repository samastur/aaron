# Windows, tabs and restoring the session

Design agreed with the user on 2026-11-02. Items marked *(Claude's call)*
were decided while writing this down and can be changed.

## Why

The user started using Aaron as a reader (the Reader profile with the
file panel) and opened several documents. Three things got in the way:

- **A file can be open only once.** The user opened a document in a
  second window, forgot about it, and later couldn't open it in a tab of
  the first window: Aaron silently brought the hidden window to the front
  instead. Other files opened fine. The user called it "wonky" and expects
  others would too. They also want the same file open in two windows on
  purpose: reading one part while editing another.
- **Tabs are hard to use.** There's no ⌘T, and no keys for switching tabs.
- **Every start begins from nothing.** The user wants the windows they
  had, with their files and profiles, back when Aaron starts.

A smaller one: the **profile menu** sits in the middle of the toolbar,
but profiles control every pane, including AI review, so it belongs last.

## Goals

1. **Toolbar order**: Files, Editor, Preview, AI actions, Review,
   **Profile** (the profile menu swaps places with the Review toggle).
2. **The same file in several windows or tabs**, kept in sync, with a
   dismissible note that tells the user.
3. **New tab** with ⌘T, close with ⌘W, **choose tabs** with ⌘1–⌘9, and
   reorder tabs by dragging.
4. **Restore the previous session** when Aaron starts normally, with an
   app-wide setting that is on by default.

The user wants related changes grouped into separate commits, roughly one
group per goal. Order:

1. Toolbar order.
2. A **spike** for opening a second copy of an open file while keeping
   DocumentGroup (a narrow workaround such as a document controller
   subclass).
3. If the spike works: the rest of goal 2, then goals 3 and 4.
   If it fails: **stop and report to the user** with what was found,
   before choosing between moving the windows onto AppKit's NSDocument
   (one document in several windows, live mirroring for free, but a
   rewrite of the app's core) and setting goal 2 aside. The user agreed
   to this. Goals 3 and 4 may go ahead meanwhile.

## Non-goals

- Live mirroring of the text between copies of a file (allowed, see
  below, but not required).
- Merging edits made in two copies at the same time.
- Restoring untitled documents, or unsaved text.
- Restoring per-window pane toggles, file panel expansion or filter text.
- Changing how ⌘N, File ▸ Open… or the file panel decide between a tab
  and a window (that follows the system "Prefer tabs" setting as today).

## Anti-goals

- **Losing text without asking.** Standing rule from the user: "Always get
  confirmation if data would be lost."
- **A copy of a file silently showing old text** after another copy saved.
- **Restoring the old session when the user asked for something
  specific** (a file, a profile).
- **Breaking what already works**: opening from Finder, the `aaron`
  command and its profile hand-off, the file panel's click-to-replace
  (takeover), autosave.

## 1. Toolbar order

Files, Editor, Preview, AI actions, Review, Profile. Nothing else changes.

## 2. The same file in several windows

**Opening.** Opening a file that is already open opens it **again**, in a
new window or tab (as the system "Prefer tabs" setting and the way it was
opened decide, exactly as for a file that isn't open). It no longer brings
the existing window forward. This applies to every way of opening: File ▸
Open…, Open Recent, Finder, the `aaron` command and the file panel
(click, ⌘-click, middle click, **Open in New Window**).

One exception stays: a plain click, in the file panel, on the file the
window itself shows does nothing. ⌘-click, middle click and **Open in New
Window** on that file open a second copy of it, which is how the user
gets "read one part, edit another" from the panel *(Claude's call; no
separate menu command is added)*.

This replaces today's file-panel rule "if the file is already open in
another window, that window comes to the front" (decision recorded in
the file panel spec). The `aaron --profile` hand-off for a file that is
already open currently switches the existing window's profile; it now
opens a new copy with that profile instead *(Claude's call, follows from
the rule above)*.

**Keeping copies in sync.** The user expects to type in only one copy and
read in the others. Agreed approach, **reload on save**:

- Each copy is its own document. Aaron autosaves after a few seconds of
  typing; when one copy's file changes on disk, the other copies without
  unsaved changes reload from disk.
- A reloading copy keeps its scroll position and selection as closely as
  it can (same character offset, clamped) *(Claude's call)*.
- The editor's undo history may be reset by a reload *(Claude's call)*.
- If two copies both have unsaved edits, the standard macOS conflict
  handling applies (the "changed by another application" prompt when
  saving). Nothing smarter is built *(Claude's call, the user expects to
  type in one copy only)*.
- This should also make a file changed by another app reload, which is
  fine and expected.
- **Live mirror** (all copies showing the same text as it is typed, each
  with its own scroll position, panes, profile and review) is better and
  allowed if the builder finds a clean way. The user: "Live mirror would
  be more seamless, but reload on save is fine as well, especially if it
  is much simpler."

**The note** (the user's idea):

- When a file is open in more than one window or tab, each copy shows a
  slim bar at the top of the window: "Also open in another window. Edits
  there appear here after they're saved." with a close button. (Wording
  for live mirror: "Also open in another window." *(Claude's call)*)
- Closing it hides it in that window only *(Claude's call)*.
- It comes back in every copy when the file is opened in yet another
  window *(Claude's call)*.
- It goes away by itself when the other copies close.

**Review sessions** are per copy: suggestions and running actions belong
to the window they were made in. A reload in a copy with open suggestions
behaves as an external change to the text does today *(Claude's call)*.

**Risk.** NSDocumentController, which SwiftUI's DocumentGroup builds on,
returns the already-open document for a file instead of opening it
again. Getting around that is the riskiest part of the work. The plan
must start this goal with a spike that proves a second copy opens, saves,
closes, autosaves and reloads correctly, before building the rest on it.

## 3. Tabs

- **File ▸ New Tab** (⌘T): opens an **empty untitled document in a new
  tab** of the front window, with that window's profile and the profile's
  panes. With no document window open, it opens a new window with the
  default profile, like ⌘N *(Claude's call)*.
- **⌘W** closes the current tab (as today).
- **Untitled tab replaced from the file panel**: an untitled document is
  replaced like any other when a file is clicked in its file panel. If it
  is empty, it goes without a question. If it has text, the normal "save
  changes?" prompt appears first *(Claude's call, from the standing rule
  about not losing data)*.
- **⌘1–⌘8** choose tabs 1–8 of the front window, **⌘9** the last tab, as
  in browsers. They are free in Aaron (AI actions use ⌥⌘1–⌥⌘9). In a
  window without tabs they do nothing *(Claude's call)*.
- **Reordering by drag** and dragging a tab out into its own window are
  built into macOS window tabs; the work includes checking they work and
  that dragging doesn't disturb a window's profile, panes or file panel.
- ⌘T is used by the standard Format ▸ Font ▸ Show Fonts command; New Tab
  takes it over *(Claude's call)*.

## 4. Restoring the session

**What is restored**: each document window with a saved file, its
**profile**, its **position and size**, and the **tab groups**: which
windows are tabs of each other, their order, and which tab is selected.
The front window is front again. Panes come from each profile as for any
opened file *(Claude's call)*. Untitled documents aren't restored, so
quitting with an untitled document that has text asks "save changes?"
for it, whatever the system "Close windows when quitting an application"
setting says *(Claude's call, from the standing rule about not losing
data)*. A file
that no longer exists is skipped quietly *(Claude's call)*.

**When.** Only when Aaron **starts normally**: from the Dock, Launchpad,
Spotlight or Finder (the app itself), or `aaron` with no arguments.

When it starts **with a file or a profile**, such as `aaron --profile
Reader notes.md`, double-clicking a Markdown file in Finder, or dropping
one on the Dock icon, it opens just that and restores nothing. The user
accepted that no rule here is perfectly unsurprising and chose this one.

**What gets saved**: only a session that **started normally** saves its
state when Aaron quits. A session started with a file or profile saves
nothing, so the next normal start brings back what the last normal
session left. The user: "if aaron in CLI is started without parameters,
then it restores the last state." *(Claude's call: saving happens on
quit, and also as windows open, close and move, so a crash loses little;
a session counts as "normal" from its start until it quits, even if files
are opened later.)*

**The setting**: app-wide (not per profile), on by default, "Reopen
windows from last time" *(Claude's call for the label; where it sits in
Settings is left to the builder, but it must be clearly app-wide, not
inside a profile's tabs)*. When off, Aaron starts as today.

**macOS's own window restoration** (which SwiftUI may already do,
depending on the system "Close windows when quitting an application"
setting) must not fight Aaron's: either Aaron's restoration replaces it,
or it is used as the mechanism, but the result must follow the rules
above in both positions of the system setting *(Claude's call)*.

**The `aaron` command:**

- `aaron` with no arguments now starts Aaron (or brings it to the front)
  instead of printing usage *(follows from the user's rule)*.
- `aaron --profile NAME` with no files opens an untitled document with
  that profile and counts as a start "with a profile" *(Claude's call)*.
- When the command starts Aaron to open files, Aaron must know at launch
  that it was started with files, even though today the script first
  launches the app with nothing (to get the token) and sends the files
  afterwards. The builder chooses how.

## Configuration

The restore setting is app-wide, so it lives next to `defaultProfile` in
`profiles.json` or in user defaults, not in profile files *(left to the
builder)*. The saved session lives in Aaron's Application Support folder
*(Claude's call)*.

## Testing

- Unit tests for what doesn't need windows: the "started normally"
  decision, encoding and decoding the saved session, tab order from a
  saved session, ⌘1–⌘9 index mapping.
- Smoke-test scenarios (Debug harness) for: the same file opened twice
  and a save in one copy reloading the other, the note appearing and
  going away, ⌘T opening a tab with the right profile, and restoring a
  saved session.
- Manual check of tab dragging (UI automation needs the user's approval).
- User guide: profiles/getting started for the toolbar order, the file
  panel page for the changed "already open" rule, a section on tabs and
  windows, the command-line page for `aaron` without arguments, settings
  for the new setting, keyboard shortcuts for ⌘T and ⌘1–⌘9. Decisions
  added to `docs/decisions.md`.

## Left to the builder

- How a second copy of an open file gets opened despite
  NSDocumentController (spike first).
- Reload on save versus live mirror.
- How Aaron learns at launch that it was started with a file or profile.
- Where the restore setting sits in Settings and where it is stored.
- Whether Aaron's restoration uses or replaces macOS's.
