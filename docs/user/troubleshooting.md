# Troubleshooting

## Preview

**"The preview could not be rendered"**: the external renderer's command
failed. The banner shows its error output. Check the command in Terminal:
paste it with the placeholders filled in and pipe the document into it, for
example `~/blog/scripts/render-post --path post.md < post.md`. Common causes:

- *command not found*: the tool is not on `PATH` for login shells. Use the
  full path in the command.
- *The command did not finish in time*: increase the renderer's timeout.
- *The command finished without printing any HTML*: the tool wrote its result
  to a file instead of standard output. Most tools accept `-o -` or similar.

**The preview has no styles or images**: the page uses root-relative URLs
(`/theme/…`). Add an [asset folder](preview.md#asset-folders) mapping that
points the URL prefix to the folder containing those files.

**The theme looks broken because it needs JavaScript**: scripts are off in
the preview by default. Turn on **Allow JavaScript in the preview** for that
renderer ([why it's off](preview.md#javascript)).

**Relative images don't show in a new document**: save it first; until then
it has no folder to load images from.

## AI actions

**The action fails immediately with "command not found"** (exit status 127):
the provider's tool is not found. Use its full path (`which claude` in
Terminal shows it) in **Settings ▸ AI ▸ Providers**.

**"not logged in" or similar**: run the tool once in Terminal and log in
(`claude`, or `codex login`).

**"The AI's answer did not contain suggestions in the expected format"**:
the AI answered in prose. The error shows the start of the answer. Run the
action again, or simplify the prompt. If it keeps happening with a
particular provider, add an instruction to the prompt such as "Answer only
with the JSON".

**"The command did not finish in time"**: long documents, or web searches in
*Fact check*, can take a while. Increase the provider's timeout, or select a
part of the document before running the action.

**Many suggestions are "Not found in text"**: the AI misquoted your text,
which happens more with smaller models. Try a different model or provider.

**Editing doesn't work**: an AI action is running. Wait, or press Cancel
(⌘.) in the review panel.

## Pelican

**The status bar says "Markdown" for a post**: the metadata block must be
at the very top, with no empty line before it, and must contain `Title:`.
Or set **Settings ▸ Pelican ▸ Pelican mode** to *Always on*.

**No tag completion**: check that a tag command is set, then use **Test
Command** in Settings. If the status bar says *Tags unavailable*, hover over
it for the error. After fixing the command, use **Edit ▸ Refresh Pelican
Tags**.

## Settings

**An alert says the settings could not be read**: the configuration file
contains invalid JSON. Aaron is using defaults and will not overwrite the
file. Click **Show File**, fix it, then use **Settings ▸ General ▸ Reload
from Disk**.
