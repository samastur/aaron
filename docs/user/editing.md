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
- **Word completion**: press Esc (or ⌥Esc) to complete the word you are
  typing from the system dictionary. On a Pelican `Tags:` line this completes
  tags instead (see [Pelican support](pelican.md#tag-completion)).
- Text substitutions that would change Markdown (smart quotes, smart dashes,
  automatic text replacement) are off, so `"`, `--` and `...` stay as typed.
  You can turn them on for a window under **Edit ▸ Substitutions**.

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
| Metadata block at the top (`Key: value` lines ended by an empty line, or YAML between `---`) | keys teal and bold, values grey |

Highlighting is approximate and never changes your text.

## Editor font

The editor uses the system font at 15 points. In **Settings ▸ General** you
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
