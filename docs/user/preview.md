# Preview

The preview panel shows the document rendered as HTML and follows your typing.
Show or hide it with the **Preview** toolbar button or **View ▸ Show/Hide
Preview** (⌥⌘P).

## Choosing a renderer

The menu at the top of the preview panel selects how the document is
rendered:

- **Markdown (built-in)**: always available, needs nothing installed.
- Any **external renderers** you have set up in **Settings ▸ Preview**, for
  example one that renders a post with your blog's real theme.

Each window remembers its own choice while it is open. When a window opens it
uses the default from **Settings ▸ Preview**: one default for Pelican posts
and one for other Markdown documents. If the default renderer no longer
exists, the built-in one is used.

## When the preview updates

- After you stop typing: 0.25 seconds for the built-in renderer, 0.8 seconds
  for external renderers (they are usually slower).
- Immediately when you switch renderer, and when you press the refresh button
  (↻) or choose **View ▸ Refresh Preview** (⇧⌘R).
- When the settings of the renderer in use change.

A small spinner next to the refresh button shows a render in progress.
The preview keeps its scroll position when it is updated.

## The built-in renderer

The built-in renderer supports CommonMark plus GitHub-style tables and
strikethrough (`~~text~~`). Raw HTML in the document is passed through, but
scripts in it do not run (see [JavaScript](#javascript)).

A metadata block at the top of the document is not shown as text. Instead
the preview shows the `Title` as a heading and the other fields in a small
table under it. This applies both to Pelican metadata (`Key: value` lines)
and to YAML front matter between `---` lines.

The preview follows the system's light or dark appearance.
Pelican-specific syntax such as `{filename}` links is not understood by the
built-in renderer; use an external renderer for an exact preview.

## Links and images in the preview

- Clicking a web link (`http`, `https`, `mailto`) opens it in your default
  browser. The preview itself never navigates away from the document.
  Links to `#anchors` within the page work.
- Images and other files referenced with relative paths (`images/photo.jpg`)
  are loaded from the document's folder. Unsaved documents have no folder, so
  relative images only appear after the first save.
- Web images and other resources (`https://…`, and also plain `http://…`)
  load normally.

## External renderers

An external renderer is any command that reads Markdown on standard input
and prints a complete HTML page on standard output. For example, it could
build a post with Pelican and print the result. Aaron sends the current text
of the editor, including unsaved changes.

The page is shown as a browser would show it: on a white background unless
its styles set another, also in dark mode.

Set them up in **Settings ▸ Preview** with **+**:

| Field | Meaning |
|---|---|
| **Name** | Shown in the renderer menu. |
| **Command** | Shell command, run by `zsh` as a login shell, so your usual `PATH` applies. May contain placeholders (below). |
| **Working directory** | Folder the command runs in. Empty: the document's folder (or your home folder for unsaved documents). `~` is allowed. |
| **{relpath} relative to** | Folder that `{relpath}` is computed from, typically your blog's content folder. |
| **Timeout** | Seconds before the command is stopped (default 30, at least 1). When it is stopped, so is everything it started. |
| **Allow JavaScript in the preview** | Let scripts in the rendered page run (off by default, see [JavaScript](#javascript)). |
| **Asset folders** | Where the preview finds files the page refers to with root-relative URLs (below). |

### Placeholders

Placeholders are replaced before the command runs; each value is quoted for
the shell, so paths with spaces work. Don't put quotes around them yourself.

| Placeholder | Value | Unsaved document |
|---|---|---|
| `{file}` | full path of the document | empty |
| `{dir}` | folder containing the document | empty |
| `{filename}` | file name, e.g. `my-post.md` | `untitled.md` |
| `{stem}` | file name without extension, e.g. `my-post` | `untitled` |
| `{relpath}` | path relative to the **{relpath} relative to** folder, e.g. `2024/my-post.md`; just the file name if the document is outside that folder | `untitled.md` |
| `{tmpfile}` | path of a temporary copy of the current text, with the document's file name | temporary `untitled.md` |

Prefer reading standard input: `{file}` points at the saved file, which does
not include unsaved changes. Use `{tmpfile}` for tools that can only read a
file. The temporary file is deleted after the command finishes.

### Asset folders

Blog themes often refer to their files with root-relative URLs such as
`/articles/theme/css/main.css`. An asset folder mapping tells the preview
where those files are on disk: the **URL prefix** `/articles/` with the
**Folder** `~/blog/articles/output` makes
`/articles/theme/css/main.css` load from
`~/blog/articles/output/theme/css/main.css`.

Mappings are tried in order. URLs that match no mapping (or whose file does
not exist) are looked up in the document's folder. URLs that try to escape a
folder with `..` are refused, and so are symbolic links that lead out of it;
links to other places inside the folder work.

### JavaScript

Scripts in the preview page don't run, whichever renderer produced it. The
preview can load files from the document's folder and from asset folders. A
script in a document's HTML, for example in a Markdown file you downloaded,
could otherwise read those files and send them elsewhere.

If your theme needs scripts to display a post properly, turn on **Allow
JavaScript in the preview** for that renderer. Only do this for documents
you trust.

### Errors

If the command fails, takes too long or prints nothing, the preview keeps the
last successful page and shows a banner with the error and the command's
error output. Use **Show more** to read long messages. The banner disappears
after the next successful render.
