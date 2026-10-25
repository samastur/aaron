# Example: setting up a Pelican blog

This walks through configuring Aaron for a Pelican blog whose repository
lives at `~/blog` and has scripts like these (the names are examples;
use your own):

- `scripts/render-post`: renders one post with Pelican's theme and plugins in
  about 0.3 s,
- `scripts/build-post`: renders a post through a full, isolated Pelican
  build (slower, but runs every plugin),
- `scripts/list-tags`: lists all tags in use, with counts (`--json`).

If the repository moves, only the paths below change.

## Quick setup

A ready-made configuration is in
[`examples/pelican-blog.json`](examples/pelican-blog.json). Adjust the
paths and script names to your blog, then add it as a
[profile](profiles.md): **Settings ▸ Profiles ▸ Import…**, choose the file
and name the profile *Blog*. If most of what you write is for the blog,
also click **Set as Default**.

Windows that open with another profile can switch to *Blog* in their status
bar or with **View ▸ Profile**.

## What it sets up

### Preview with the real theme

Two external renderers, in **Settings ▸ Preview**:

| | Pelican (fast) | Pelican (full build) |
|---|---|---|
| Command | `~/blog/scripts/render-post --path {relpath}` | `~/blog/scripts/build-post --path {relpath}` |
| {relpath} relative to | `~/blog/articles/content` | same |
| Timeout | 30 s | 60 s |
| Asset folder | `/articles/` → `~/blog/articles/output` | same |

Both read the unsaved text from standard input. `{relpath}` tells them where the post
sits in the content folder, so `{filename}` links resolve as on the site.
The theme's styles, fonts and images are referenced as `/articles/…` and
come from the last site build in `articles/output`. Run `make html` in
`articles/` once if that folder is missing or outdated.

**Default for Pelican posts** is *Pelican (fast)*; plain Markdown documents
keep the built-in renderer. Switch to *Pelican (full build)* in the preview
panel when you need plugins that only run in a full build.

### Tag completion

**Settings ▸ Pelican ▸ Tag command** is
`~/blog/scripts/list-tags --json`, with a 20 second timeout. It
reads tags the way Pelican does, so completion offers exactly the tags on
the site, most used first.

### Help for your plugins

**Settings ▸ Pelican ▸ Plugins command** is

```
cd ~/blog/articles && .venv/bin/python -c 'import pelicanconf; [print(p) for p in pelicanconf.PLUGINS]'
```

It reads `PLUGINS` from `pelicanconf.py` with the blog's own Python, so
**Help ▸ Markdown Help** (⇧⌘M) on a post explains `simple_footnotes`
(`[ref]…[/ref]`) and `sitemap`, and follows along when you add plugins.

### Writing a new post

1. **File ▸ New Pelican Post** (⌥⌘N) and fill in the title and tags; tags
   complete as you type.
2. Save it into `~/blog/articles/content/`. Until it is
   saved there, `{relpath}` is `untitled.md` and links to other posts may not
   resolve in the preview.
3. Run **Review ▸ Grammar and spelling** (⌥⌘1), then **Style** (⌥⌘3), and
   work through the suggestions. **Fact check** (⌥⌘2) searches the web and
   takes longer.

If your blog has a script that creates a draft, it can open the draft in
Aaron with the blog profile, whatever the default is:
`aaron --profile Blog "$file"` (see [The `aaron` command](command-line.md)).

