# Writing and editing

## The editor

The editor is a plain-text editor: what you type is exactly what is saved.
Long lines wrap at the window edge, which suits Markdown written with one
paragraph per line. Lines are never wrapped in the file itself.

Things that behave like in other Mac text editors:

- **Undo and redo** (⌘Z, ⇧⌘Z) for every change, including accepted AI
  suggestions (see [AI review](review.md#undo)).
- **Find and replace** (⌘F, ⌥⌘F) through the find bar; ⌘G and ⇧⌘G go to
  the next and previous match.
- **Spelling** is checked as you type (red dotted underlines). Use
  **Edit ▸ Spelling and Grammar** to turn it off or to check grammar too.
- **Markdown reference**: **Help ▸ Markdown Help** (⇧⌘M), see
  [Markdown Help](markdown-help.md).
- **Word completion**: press Esc (or ⌥Esc) to complete the word you are
  typing from the system dictionary. On a Pelican `Tags:` line this completes
  tags instead (see [Pelican support](pelican.md#tag-completion)).
- Text substitutions that would change Markdown (smart quotes, smart dashes,
  automatic text replacement) are off, so `"`, `--` and `...` stay as typed.
  You can turn them on for a window under **Edit ▸ Substitutions**.

## Formatting

The **Format** menu adds Markdown around the selection. The shortcuts are
the usual ones from Mac editors and web apps.

| Command | Shortcut | What it does |
|---|---|---|
| Bold | ⌘B | `**text**`; again removes it. Also removes `__text__`. |
| Italic | ⌘I | `*text*`; again removes it. Also removes `_text_`. Bold and italic combine to `***text***`. |
| Link | ⌘K | `[text](url)`. A URL on the clipboard is used as the link; a selected URL becomes the link and the caret goes to the text. |
| Quote | ⌘' | `> ` before each selected line; if they are all quoted already, removes one level. |
| Insert HTML… | ⇧⌘H | Asks for HTML (for example an embed code) and inserts it in place of the selection. HTML that starts with a block element such as `<div>`, `<figure>` or `<iframe>` gets an empty line before and after it, which Markdown needs to leave it alone. |

Bold and italic use the word at the caret if nothing is selected, or insert
an empty pair (`****`) with the caret in the middle. Spaces at the ends of
the selection are left outside the markers. Each command is one step to
undo.

## Syntax highlighting

Aaron highlights Markdown lightly so the text stays readable:

| Element | Look |
|---|---|
| Headings (`#` … `######` followed by a space) | bold, larger for higher levels |
| `**strong**`, `__strong__` | bold |
| `*emphasis*`, `_emphasis_` | italic (underscores inside words, like `snake_case`, are left alone) |
| `` `inline code` `` and fenced code blocks (```` ``` ```` or `~~~`) | monospaced, purple; nothing inside code is highlighted |
| Links `[text](url)` and `<https://…>` | link text blue, URL grey |
| Block quotes (`>`) | grey |
| List markers (`-`, `*`, `+`, `1.`) | orange |
| Metadata block at the top (`Key: value` lines ended by an empty line, or YAML between `---`) | keys bold, dark blue (teal in dark mode); values grey |

Highlighting is approximate and never changes your text.

## Editor font

The editor uses the system font at 16 points. In **Settings ▸ General** you
can change the size (9–36 points) and switch to a monospaced font. The
changes apply to all open windows immediately.

## Status bar

The bar at the bottom of the window shows:

- **Words** and **characters** in the document's body. A metadata block at the
  top (Pelican `Key: value` lines or YAML front matter) is not counted.
- **N tags**, for Pelican posts, when the tag list has been loaded, or
  **Tags unavailable** if loading failed (hover over it to see why).
- **Markdown** or **Pelican**: how the document is treated. See
  [Pelican support](pelican.md#pelican-mode).

## Editing while the AI is working

While an AI action is running, the document is read-only, so the text the AI
is reviewing cannot change underneath it. Editing becomes possible again as
soon as the answer arrives or you cancel. See [AI review](review.md).
