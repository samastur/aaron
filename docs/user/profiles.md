# Profiles

A **profile** is a complete set of settings: the editor font, preview
renderers, AI providers and actions, and the Pelican settings. You might
keep a *Plain* profile for ordinary Markdown and a *Blog* profile with your
blog's preview scripts, tag command and post template.

One profile is the **default**. Every window starts with it, whether the
file was opened from Finder, **File ▸ Open…**, the `aaron` command, or is
new. Aaron does not remember profiles per file or per folder.

## Switching a window's profile

Each window uses one profile, shown at the right end of its status bar.
Choose another one in any of these places:

- the profile name in the status bar,
- the **Profile** menu in the toolbar (slider icon),
- **View ▸ Profile**.

The whole window follows the new profile right away: the panes it shows,
Pelican detection and tags, the renderer menu and the preview, the AI
actions, the editor font and Markdown Help. If the window's renderer doesn't exist in the new
profile, the preview switches to the built-in renderer. Review suggestions
stay, because they belong to the text. An AI action that is already running
finishes with the settings it started with.

## Panes shown when a file opens

**Settings ▸ General ▸ Panes** chooses which parts of the window a profile
shows: the **Editor**, the **Preview** and the **AI review** panel. They
apply when a window opens a file with the profile and when a window
switches to it. Changing them doesn't rearrange windows that are already
open. Afterwards you can still show or hide each pane yourself.

To read Markdown rather than write it, for example documentation, make a
profile with only **Preview** on. Its windows open as rendered pages; press
⌥⌘E to bring the editor back when you want to change something.

The editor and the preview can't both be off, since the window would be
empty. While the editor is hidden, AI actions still run on the document,
and accepted suggestions change it. To undo one, tick **Show handled** in
the review panel and click **Revert**
([AI review](review.md#changing-your-mind)); ⌘Z only works on changes made
while the editor is shown.

## Managing profiles

**Settings ▸ Profiles** lists the profiles, with the default marked. Select
one to see its details.

- **+** adds a copy of the selected profile, named "… copy". Rename it in
  the **Name** field and press Return.
- **−** deletes the selected profile, after asking. The default profile and
  the last profile can't be deleted. Windows that used a deleted profile
  switch to the default.
- **Set as Default** makes the selected profile the one new windows use.
- **Import…** adds a profile from a configuration file, such as one copied
  from another Mac or the [example blog setup](example-blog-setup.md). The
  file may contain only some settings; the rest get their defaults.
- **Show in Finder** and **Reload All from Disk** work on the profile files
  (below).

Names can't be empty, start with "." or contain "/" or ":", and two
profiles can't have the same name, ignoring case.

## Editing a profile

The **General**, **Preview**, **AI** and **Pelican** tabs each have a
**Profile** menu at the top: they edit the profile chosen there. Settings
opens on the profile of the window that was in front. Changes apply at once
to every window using that profile and are saved automatically.

**Settings ▸ General ▸ Restore Defaults…** resets the chosen profile only.

## Where profiles are stored

```
~/Library/Application Support/Aaron/
  profiles.json        which profile is the default
  Profiles/
    Default.json
    Blog.json
```

Each profile is a configuration file in the format described in
[Settings](settings.md#the-configuration-file), named after the profile.
You can copy, edit or put these files under version control; after editing
one by hand, choose **Reload All from Disk**. A profile file Aaron can't
read is listed with an error and left untouched until it is fixed.

The first time this version of Aaron starts, it turns an existing
`config.json` into the profile **Default** and renames the old file to
`config.json.migrated`.
