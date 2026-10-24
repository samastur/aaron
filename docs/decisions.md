# Decisions made without consultation

You asked me to build the first version without checking in with you.
These are the calls I would otherwise have asked you about, with the reasoning.
Each one can be revisited.

## Product

1. **Name: "Aaron".** Taken from the project directory. The bundle identifier
   is `net.gaivo.Aaron`.
2. **AI goes through command-line tools, not HTTP APIs.** You asked to use
   existing Claude/OpenAI subscriptions. Providers are configurable shell
   commands that read the prompt on stdin and print the answer. The defaults
   are `claude -p` (Claude Code) and `codex exec` (OpenAI Codex). No API keys
   are stored.
3. **Default Claude invocation disables tools** (`--tools ""`), which makes
   checks faster and keeps the AI from touching files. For fact checking with
   web access, define a second provider that allows `WebSearch`/`WebFetch`.
   The user guide shows how.
4. **Review mode is a separate mode.** It is entered from the toolbar or by
   running an AI action. While an action runs the editor is read-only (with a
   Cancel button). After results arrive you can keep editing. Edits shift the
   highlights that follow them; suggestions whose text you changed become
   "stale" and can only be dismissed. This follows the ChatGPT discussion:
   block edits while the AI is working, and shift/invalidate afterwards.
5. **Results from several actions accumulate** in one list, labelled by
   action, until you clear them or leave review mode. They are not saved with
   the document.
6. **Running an action on a selection** sends the whole document for context
   but asks the AI to comment only on the selected passage.
7. **Unresolvable suggestions are shown, not hidden.** If the AI's quotation
   cannot be found in the text, or matches more than one place, the
   suggestion appears in the list marked "Not found in text", without a
   highlight, and can only be dismissed. One relaxation: if the surrounding
   context does not match but the quoted text occurs exactly once, that
   occurrence is used.
8. **Undoing an accepted suggestion** restores the text (normal ⌘Z) but does
   not move the suggestion back to "open".
9. **Pelican mode is detected automatically**. A document counts as a Pelican
   post when it starts with a `Key: value` metadata block containing `Title:`.
   Detection can be forced on or off globally in Settings.
10. **Tag completion** works on the `Tags:` metadata line. The completion
    list opens as you type (after the first character of a tag) and also on
    Esc / ⌥⎋ (the standard macOS completion keys). Candidates are ranked by
    prefix match first, then by how often the tag is used, then by substring
    match. Tags already on the line are left out.
11. **Preview renderers are chosen per window** from a menu in the preview
    panel. Settings decide the default for Pelican documents and for other
    documents separately. The built-in renderer is always available.
12. **The built-in preview strips the metadata block** and shows the title
    and metadata as a small header above the rendered text, so previews of
    Pelican posts are still readable without a Pelican renderer.
13. **External renderers get the unsaved buffer on stdin.** They also get the
    file's location through placeholders, so tools that need the real path
    (for example for `{filename}` links) still work.
    `{tmpfile}` is a temporary copy of the buffer that has the original file
    name, for tools that cannot read stdin.
14. **Theme assets for external previews** (CSS, images under `/articles/…`)
    are served from local directories that you map in the renderer's settings.
    Without a mapping, relative URLs resolve against the document's folder.
15. **Configuration is one JSON file** in Application Support. It is editable
    in the Settings window and by hand. There is no per-project
    configuration in this version. Commands can use placeholders such as
    `{dir}` to adapt to where a document lives, which covers the blog case.
16. **Editor font**: the system font at 15 pt by default, with a Settings option
    to switch to monospaced and to change the size. Lines wrap softly
    (your paragraphs are long single lines).
17. **A status bar** shows the word count, character count and document mode
    (Markdown or Pelican). This was not requested but is cheap and useful when
    writing posts.
18. **Syntax highlighting** is light: headings, emphasis, inline code and code
    blocks, links, block quotes, list markers and the metadata block.

## Technical

19. **SwiftUI app with an AppKit `NSTextView`** for editing. SwiftUI
    `DocumentGroup` handles documents (open, save, autosave, versions,
    recent files). `NSTextView` provides undo, native completion popups,
    find, spelling and highlighting.
20. **The logic lives in a Swift package** (four libraries) that is tested
    with `swift test`. The Xcode project, generated with XcodeGen from
    `App/project.yml`, contains only the app layer and UI tests. The
    generated `.xcodeproj` is not committed.
21. **swift-markdown (Apple, cmark-gfm)** is the built-in Markdown engine:
    CommonMark plus GitHub tables and strikethrough. It is the only
    third-party dependency.
22. **The app is not sandboxed**, because it has to run external tools
    (Pelican scripts, `claude`, `codex`) and read theme assets anywhere on
    disk.
23. **Commands run through `/bin/zsh -l -c`** so that your login `PATH`
    applies, and `~/.local/bin`, `/opt/homebrew/bin` and `/usr/local/bin` are
    added to `PATH` as well, because apps started from Finder do not inherit
    your shell's environment.
24. **Timeouts**: 30 s for preview commands, 15 s for tag commands and 300 s
    for AI providers. Each can be changed per command.
25. **Commands without a working directory run in your home folder**, not in
    `/`, which is where apps started from the Finder would otherwise run them.
26. **The preview may load plain `http://` resources**
    (`NSAllowsArbitraryLoadsInWebContent`). Old posts embed images over HTTP,
    and the preview should look like the published page. App Transport
    Security still applies to everything outside the web view.
27. **Windows open at 1400 × 860 points**, so that the editor, the preview and
    the review panel all fit.
28. **After an AI action, a one-line summary** says how many suggestions it
    made and how many could not be located, or that it found nothing. This was
    not requested; without it an empty result looked like a failure.
29. **An unreadable configuration file is never overwritten.** Aaron shows an
    alert, uses the defaults and stops saving until the file has been reloaded
    successfully, so hand edits are not lost to a typing mistake.
30. **A Debug-only test harness is built into the app** so that it can be
    checked end to end without macOS UI-automation permission (see
    `docs/developer/testing.md`). It is compiled out of Release builds.
31. **Scripts don't run in the preview** unless enabled per renderer. The
    preview serves files from the document's folder, so a script in a
    downloaded document could read neighbouring files and send them out.
32. **Commands run in their own process group**, so a timeout or cancel stops
    everything they started (e.g. Pelican subprocesses), not just the shell.
33. **A metadata block must end with an empty line** (or the end of the
    document). Otherwise a document starting with "Note: …" would lose its
    first line in the preview and word count.
34. **Metadata keys are dark blue in light mode**, teal in dark mode (your
    request; teal lacked contrast on white).
35. **The review panel uses a plain list with pastel selection** instead of
    the system list, whose blue/grey selection made text hard to read. Text
    is 14 pt (12 pt for labels).
36. **Handled suggestions can be reversed** with Revert (accepted) and
    Reopen (dismissed) as long as their text is unchanged. ⌘Z after
    accepting restores the text but not the suggestion; Revert does both.
37. **Markdown Help is ⇧⌘M.** ⌘?, the usual help shortcut, is reserved by
    macOS for the Help menu's search field.
38. **Plugin help is matched by name.** Aaron ships help for nine common
    plugins. For any others, you add `<plugin>.md` files to a help folder.
    The plugin list comes from a configurable command, so Aaron doesn't
    need to understand `pelicanconf.py`.
39. **External previews are shown on white, as in a browser.** The web view
    used to be transparent, so a page that sets no background of its own
    showed black text on the dark window in dark mode. The built-in
    renderer declares `color-scheme: light dark` and still follows the
    appearance.
