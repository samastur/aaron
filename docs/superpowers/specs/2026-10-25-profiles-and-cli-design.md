# Configuration profiles and the `aaron` command

Design agreed with the user on 2026-10-25. Items marked *(Claude's call)*
were decided while writing this down and can be changed.

## Why

The user writes both plain Markdown and posts for a Pelican blog. Today Aaron has exactly one configuration
(`~/Library/Application Support/Aaron/config.json`), so using the blog setup
means either living with it for every document or starting Aaron with
`AARON_CONFIG_PATH`. The user wants:

1. **Profiles**: several named configurations, for example *Plain* and
   *Blog*, one of them the default, switchable per open window.
2. **An `aaron` command**, so the blog's script that creates a new draft
   (which today opens it in another editor) can open a newly created draft in Aaron, with the blog
   profile.

## Goals

- A profile is a complete configuration: everything `Configuration` holds
  today (editor, preview renderers and defaults, AI providers and actions,
  Pelican settings). No setting is shared across profiles.
- Exactly one profile is the default. Every newly opened or created window
  starts with the default profile.
- Each window can switch to another profile at any time. The whole window
  follows it: highlighting and font, renderer menu and preview, AI actions,
  tags and tag completion, Markdown Help.
- Editing a profile in Settings affects every window that uses it, as edits
  to the single configuration do today.
- `aaron [--profile NAME] FILE...` opens existing files in Aaron, starting it
  if needed, and returns immediately.
- An in-app way to install the `aaron` command, and a script that installs
  the app into `/Applications`.

## Non-goals

- Remembering a profile per file or per folder, or choosing one
  automatically. The user said this can wait. (Leave room for it: a window's
  profile is chosen in one place.)
- Creating files from the command line, waiting for the window to close
  (`--wait`), or line numbers.
- Changing the blog's draft script. It lives in the user's other
  repository; the user gets the one-line change to make themselves.

## Anti-goals

- Installing anything into `/opt/homebrew/bin` (or any Homebrew prefix). The
  user said explicitly: Aaron is not installed through Homebrew, and a home
  version there could clash with a Homebrew one later.
- Losing or silently rewriting the user's existing `config.json`.
- Overwriting a file the user did not create through Aaron (for example an
  existing, non-symlink `~/.local/bin/aaron`).

## Storage

```
~/Library/Application Support/Aaron/
  profiles.json          {"defaultProfile": "Default"}
  Profiles/
    Default.json         one Configuration, same format as config.json today
    Blog.json
```

- A profile's **name is its file name** without `.json`. Renaming a profile
  renames the file. Names must be non-empty, unique ignoring case, and must
  not contain `/` or `:` or start with `.` *(Claude's call)*.
- Each profile file is decoded leniently, exactly as `config.json` is today.
  A profile file that cannot be parsed is listed with an error and is not
  overwritten until it is fixed and reloaded (today's `fileIsUnreadable`
  behaviour, per profile). Other profiles keep working.
- `profiles.json` missing or naming a profile that doesn't exist: the first
  profile alphabetically is the default.
- **Migration**: on launch, if `Profiles/` does not exist, it is created with
  one profile, **Default**: the contents of `config.json` if it exists,
  otherwise the built-in defaults. `config.json` is then renamed to
  `config.json.migrated` (kept, not deleted) *(Claude's call)*.
- If `Profiles/` exists but is empty (the user deleted everything by hand),
  a **Default** profile with built-in defaults is created.
- **`AARON_CONFIG_PATH` is replaced by `AARON_SUPPORT_DIR`**, which overrides
  the whole folder above. Tests, the smoke-test script, the scheme and the
  docs move to it *(Claude's call)*. It is only for testing and development.

## Settings window

- Settings edits one profile at a time, the **selected profile**, shown in a
  picker at the top of every settings tab (or in the window's toolbar,
  builder's call on the exact placement). Settings opens on the profile of
  the front document window, or the default if there is none
  *(Claude's call)*.
- A **Profiles** section (its own tab, first) lists all profiles, marks the
  default, and has:
  - **Add**: a copy of the selected profile, named "<name> copy", then
    renamed in place;
  - **Rename**;
  - **Delete**, with a confirmation. The default profile cannot be deleted
    and the last profile cannot be deleted. Windows using a deleted profile
    switch to the default;
  - **Set as Default**;
  - **Import…**: pick a JSON file (such as
    `docs/user/examples/pelican-blog.json`), give it a name, and it
    becomes a new profile (decoded leniently like any profile, so a partial
    file gets defaults for the rest);
  - **Reveal in Finder** for the profiles folder.
- The existing General-tab buttons now act on the selected profile:
  **Restore Defaults** resets it, **Reload from Disk** reloads all profiles
  and `profiles.json`, and the path shown is the profile's file.
- Renaming a profile keeps every window that uses it on it.

## Choosing a window's profile

- Every document window has a current profile, initially the default (or
  the one given by `aaron --profile`).
- Switch it from:
  - a **Profile** menu in the window toolbar, showing the current name;
  - **View ▸ Profile ▸ <names>** (checkmark on the current one);
  - clicking the profile name in the status bar, which is always shown
    *(Claude's call)*.
- Switching a profile behaves like editing the configuration today
  (`DocumentWindowModel.configurationChanged`): Pelican detection is redone,
  the renderer falls back to the new profile's default if the current
  renderer id doesn't exist there, the preview re-renders, tags are loaded
  with the new profile's tag command, the editor font changes.
- **Review suggestions are kept** when switching; they belong to the text.
  A running AI action is not affected (it already captured its provider).
- **File ▸ New Pelican Post** uses the default profile's template, like any
  new window *(Claude's call)*.
- **Markdown Help** uses the profile of the window it was opened from
  (its plugins command and help folder).
- The window's profile is not saved anywhere; reopening a file uses the
  default again.

## The `aaron` command

```
aaron [--profile NAME] FILE...
aaron --list-profiles
aaron --help
```

- Opens each FILE in Aaron and returns as soon as Aaron has been asked to
  open them (it does not wait for the window). Relative paths are resolved
  against the current directory.
- A FILE that does not exist: error on stderr naming it, exit status 1,
  nothing is opened *(Claude's call: check all files before opening any)*.
- `--profile NAME`: windows opened by this call use profile NAME instead of
  the default. Unknown NAME: error listing the available profiles, exit 1.
  Name matching ignores case *(Claude's call)*.
- A FILE already open in Aaron: its window comes to the front; with
  `--profile`, it also switches to that profile *(Claude's call)*.
- Without `--profile`, behaviour equals `open -a Aaron FILE`.
- The command belongs to a specific app copy: it opens the files in the
  Aaron.app it was installed from (resolving its own symlink), so a Debug
  build and the installed app do not get mixed up.
- **Debug and installed copies are kept apart** *(Claude's call)*: the
  Debug configuration gets its own bundle identifier
  (`net.gaivo.Aaron.debug`), display name *Aaron Debug* and support folder
  (`~/Library/Application Support/Aaron Debug/`), so LaunchServices never
  hands a request to the wrong copy and two running copies never write the
  same profile files. The Release build keeps `net.gaivo.Aaron` and
  `Aaron/`, where the migration of the existing `config.json` happens.
- **Only the command may choose a profile** *(Claude's call)*. Opening a file
  must not be a way for a web page or another app to run a profile's
  commands on a file of its choosing. If a URL scheme is used, requests must
  carry a random token that Aaron writes, readable only by the user, to its
  support folder (`cli-token`, mode 0600) and the script reads; requests
  without the right token are ignored and logged.
- Suggested mechanism (builder may choose another that meets the above):
  a zsh script shipped in `Aaron.app/Contents/Resources/aaron`, which
  validates arguments, then calls
  `open -a <its Aaron.app> 'aaron://open?token=T&profile=NAME&path=/abs/file'`.
  Aaron registers the `aaron` URL scheme, opens the file through
  `NSDocumentController`, and applies the profile to that document's window.
  Profile validation can read `Profiles/` directly (honouring
  `AARON_SUPPORT_DIR`).

### Installing it

- **Aaron ▸ Install Command Line Tool…** creates `~/.local/bin` if needed and
  puts a symlink `~/.local/bin/aaron` → the script inside the running
  Aaron.app.
  - An existing symlink is replaced. An existing regular file is not touched:
    Aaron explains and stops.
  - Afterwards Aaron reports whether `~/.local/bin` is on the PATH of the
    user's login shell (checked by running it, as commands are run today),
    and if not, shows the line to add to `~/.zprofile`.
  - Never `/opt/homebrew/bin`, `/usr/local/bin`, or anywhere needing admin
    rights.
- **`scripts/install.sh`** builds the Release configuration and copies
  `Aaron.app` to `/Applications`, replacing an older copy (asking first if
  Aaron is running). After that, install the command from the installed app.

### For the blog

The user changes the draft script to run
`["aaron", "--profile", "Blog", filename]`. The user-facing docs give this example.

## Documentation and tests

- User docs: a new page on profiles; `settings.md`, `example-blog-setup.md`
  (import the example as a profile instead of copying it over
  `config.json`), `getting-started.md` (installing the app and the
  command), `keyboard-shortcuts.md` if anything gets a shortcut, and a page
  or section for the `aaron` command.
- Developer docs: `design.md` (profile store, URL scheme), `testing.md`
  (`AARON_SUPPORT_DIR`), `decisions.md` entries for every *(Claude's call)*.
- TDD as for the rest of the project: package tests for the profile store
  (migration, naming rules, default resolution, unreadable profiles,
  rename/delete), the URL parsing and the command's argument handling;
  hosted tests for the window model switching profiles; smoke and UI tests
  for switching in a window, the Settings profile tab, and opening via the
  command (the script can be run against the Debug build).

## Left to the builder

- Exact Settings layout for the profile picker and Profiles tab.
- How the profile store is split between AaronCore and the app.
- Whether the command is a zsh script or a small Swift executable, as long
  as it behaves as above.
- Toolbar icon and wording details.
