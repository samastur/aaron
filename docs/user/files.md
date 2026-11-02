# The file panel

The file panel on the left of the window lists the Markdown files in one
folder, the profile's **root folder**, and in the folders below it. Click a
file to open it.

Show or hide it with the **Files** toolbar button or **View ▸ Show/Hide
Files** (⌃⌘S). Whether new windows show it is set per profile in
**Settings ▸ General ▸ Panes**.

## What it lists

- Only files with one of the profile's **extensions** (by default `.md` and
  `.markdown`), and only folders that lead to such files. A folder with
  nothing but images or code in it doesn't appear.
- No hidden files or folders: names starting with `.`, and folders macOS
  hides, such as `~/Library`.
- No folders named in **Ignored folders** (by default `node_modules`), at
  any depth.
- **iCloud Drive**: when the root contains your home folder's `Library`,
  iCloud Drive appears as its own **iCloud Drive** entry at the top.

Folders come first, then files, sorted the way Finder sorts them. The file
the window shows is selected, and its folders are opened to show it.

Aaron finds the files with **Spotlight**, so even a large root such as your
home folder lists quickly, and files you add, rename or delete appear and
disappear on their own. While the first search runs, a small progress
indicator spins in the panel's header.

Spotlight doesn't index some places: hidden folders, some external drives,
and folders excluded in **System Settings ▸ Spotlight**. When the root is
such a place, the panel shows every folder instead and reads it when you
open it, and the filter is turned off. The first time Aaron looks into
Desktop, Documents or Downloads, macOS asks for permission once.

## Filter

Type in the **Filter** field to list the files whose **name** contains the
text, ignoring case and accents. Each result shows the folder it is in,
relative to the root. Press ↓ to move into the results and Return to open
one; Esc clears the filter and brings the tree back.

## Opening files

- **Click** a file to open it in the same window. Your edits to the
  previous document are saved automatically. The window keeps its profile,
  panes, open folders and filter.
- **⌘-click** or **middle-click** a file, or choose **Open in New Window**
  from its context menu, to open it in a new window.
- A file that is already open in another window opens again, so you can
  read one part while editing another (see
  [Windows and tabs](windows-and-tabs.md)). Use ⌘-click or **Open in New
  Window** on the window's own file for a second copy of it; a plain click
  on it does nothing.

If the window has AI suggestions you haven't accepted or dismissed yet, or
an AI action is running, opening another file in the same window would
lose them, so Aaron asks first: **Open in New Window** (the default),
**Replace** or **Cancel**.

Windows that are tabs keep their place in the tab bar. A window in full
screen may briefly show the switch as it moves to the new document.

## Changing the root folder

- Click the folder name at the top of the panel and choose **Choose Root
  Folder…** or **Use Home Folder**.
- Right-click a folder in the panel and choose **Use as Root**.
- Or set **Root folder** in **Settings ▸ General ▸ Files**.

The root belongs to the profile, so all windows using that profile follow
the change. If the folder no longer exists, the panel says **Folder not
found**; choose another one from the header menu.
