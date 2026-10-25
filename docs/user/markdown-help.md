# Markdown Help

**Help ▸ Markdown Help** (⇧⌘M) opens a window with a Markdown reference. It
is also listed in the **Window** menu once opened. Pressing ⌘? opens the
Help menu with its search field, where **Markdown Help** is the first item.

The help is written for the document that was in front when you opened it:

- **For every document** it shows Markdown syntax. For each feature it
  says whether Aaron's built-in preview shows it and whether Pelican's
  default Markdown processor supports it. Some features are only in one,
  for example strikethrough (preview) or footnotes (Pelican).
- **For Pelican posts** it adds Pelican's syntax:
  - the metadata fields;
  - links to other content (`{filename}`, `{static}`, `{attach}`, …);
  - code highlighting;
  - a section on the plugins your site uses (below).

The title bar says which kind of document the help is for. Open the help
again from another window to switch, or use the refresh button (↻) to load
it again, for example after changing the plugin list.

## Plugins

To list your site's plugins, Aaron runs the **plugins command** from
**Settings ▸ Pelican ▸ Markdown Help** of the window's
[profile](profiles.md) (its help folder is used too). The command prints the plugin names:

- one per line, or
- as a JSON list (`["a", "b"]`), or
- as `{"plugins": [...]}`.

It runs in the post's folder; `{dir}`, `{file}` and the other
[placeholders](preview.md#placeholders) refer to the post. For a typical
Pelican site that keeps its plugins in `PLUGINS` in `pelicanconf.py`:

```
cd ~/blog && .venv/bin/python -c 'import pelicanconf; [print(p) for p in pelicanconf.PLUGINS]'
```

Plugin names are matched without their package prefix and without regard to
case or dashes, so `pelican.plugins.simple_footnotes`, `simple-footnotes`
and `simple_footnotes` are the same.

Aaron has help for these plugins: `liquid_tags`, `neighbors`,
`readtime`, `related_posts`, `render_math`, `series`, `simple_footnotes`,
`sitemap` and `summary`. Other plugins are listed with a note saying no help
is available.

### Your own help files

Set **Help folder** (same settings section) to a folder of Markdown files
named after the plugin, such as `my_plugin.md` or `simple_footnotes.md`.
A file there replaces Aaron's own help for that plugin, or adds help for a
plugin Aaron doesn't know. Write them like any Markdown document; they are
shown under the plugin's name.

If the plugins command is not set, the Pelican help explains how to set it.
If it fails, the help shows its error instead of the plugin list.
