# Settings and the configuration file

Open **Aaron ▸ Settings…** (⌘,). Changes take effect immediately in all
windows and are saved automatically.

## General

- **Font size** and **Use a monospaced font**: the editor's font
  ([Writing and editing](editing.md#editor-font)).
- **Configuration file**: where the settings are stored, with buttons to
  **Show in Finder**, **Reload from Disk** (after editing the file by hand)
  and **Restore Defaults…**. Restoring the defaults asks for confirmation and
  removes all renderers, providers and actions you added.

## Preview

- **Default for Markdown documents** and **Default for Pelican posts**: the
  renderer a new window starts with.
- **External renderers**: add (**+**), remove (**−**) and reorder (arrows)
  renderers, and edit the selected one. See
  [Preview](preview.md#external-renderers) for the fields.

## AI

Two tabs, **Actions** and **Providers**, each a list with **+**, **−** and
arrows, and the details of the selected item. See
[Setting up AI actions and providers](ai-setup.md).

## Pelican

**Pelican mode**, the **tag command** with its working directory and
timeout, **Test Command**, and the **new post template**. See
[Pelican support](pelican.md).

## The configuration file

Settings live in one JSON file:

```
~/Library/Application Support/Aaron/config.json
```

The file is created the first time you change a setting. You can edit it in
any text editor. Then use **Settings ▸ General ▸ Reload from Disk**, or
restart Aaron. Every key is optional: missing keys get their default values,
so a file can contain just what you want to change. `~` may be used in all
paths.

If the file cannot be read (for example after a typing mistake), Aaron
shows an alert with the error, uses the defaults, and **does not overwrite
the file** until it has been reloaded successfully, so your edits are not
lost. Fix the file and choose **Reload from Disk**.

To use a different file, start Aaron with the environment variable
`AARON_CONFIG_PATH` set to its path, for example from Terminal:
`AARON_CONFIG_PATH=~/aaron-test.json /Applications/Aaron.app/Contents/MacOS/Aaron`.

### Reference

```json
{
  "editor": {
    "fontSize": 15,
    "monospaced": false
  },
  "previewRenderers": [
    {
      "id": "pelican",
      "name": "Pelican",
      "command": "~/blog/scripts/render-post --path {relpath}",
      "workingDirectory": null,
      "baseDirectory": "~/blog/articles/content",
      "timeoutSeconds": 30,
      "allowsJavaScript": false,
      "assetMappings": [
        { "urlPrefix": "/articles/", "directory": "~/blog/articles/output" }
      ]
    }
  ],
  "defaultRenderer": {
    "markdown": "builtin",
    "pelican": "pelican"
  },
  "aiProviders": [
    { "id": "claude", "name": "Claude", "command": "claude -p --tools \"\" --no-session-persistence", "timeoutSeconds": 300 }
  ],
  "aiActions": [
    { "id": "grammar", "name": "Grammar and spelling", "prompt": "Find spelling mistakes…", "providerID": "claude" }
  ],
  "pelican": {
    "detection": "automatic",
    "tagsCommand": "~/blog/scripts/list-tags --json",
    "tagsWorkingDirectory": null,
    "tagsTimeoutSeconds": 15,
    "newPostTemplate": "Title: \nDate: {date}\nCategory: \nTags: \nSlug: \nStatus: draft\n\n"
  }
}
```

| Key | Default | Meaning |
|---|---|---|
| `editor.fontSize` | `15` | Editor font size in points; values outside 9–36 are treated as 9 or 36. |
| `editor.monospaced` | `false` | Use a monospaced editor font. |
| `previewRenderers` | `[]` | External renderers. `id` is any unique text (generated if missing), referenced by `defaultRenderer`. `command` is required. `workingDirectory` and `baseDirectory` are optional. `timeoutSeconds` defaults to 30. |
| `previewRenderers[].assetMappings` | `[]` | `urlPrefix` → `directory` pairs, tried in order. Mappings with an empty `directory` are ignored. |
| `previewRenderers[].allowsJavaScript` | `false` | Let scripts in the rendered page run. |
| `defaultRenderer.markdown`, `defaultRenderer.pelican` | `"builtin"` | Renderer `id` for new windows; `"builtin"` is the built-in Markdown renderer. |
| `aiProviders` | Claude, Claude (web), Codex | `id`, `name`, `command`, `timeoutSeconds` (default 300). If the key is present, it replaces the whole default list. |
| `aiActions` | Grammar and spelling, Fact check, Style | `id`, `name`, `prompt`, `providerID`. If the key is present, it replaces the whole default list. |
| `pelican.detection` | `"automatic"` | `"automatic"`, `"always"` or `"never"`. |
| `pelican.tagsCommand` | `""` | Command printing the known tags; empty disables tag completion. |
| `pelican.tagsWorkingDirectory` | the post's folder | Folder the tag command runs in. |
| `pelican.tagsTimeoutSeconds` | `15` | Timeout of the tag command. |

All timeouts are in seconds; values below 1 count as 1.
| `pelican.newPostTemplate` | see [Pelican support](pelican.md#new-posts) | Text of **File ▸ New Pelican Post**. |

All commands run with `/bin/zsh -l -c`, with `~/.local/bin`,
`/opt/homebrew/bin` and `/usr/local/bin` added to `PATH`. When a command times
out or is cancelled, it and every process it started are stopped (and killed
if they don't stop within two seconds).

Changes are written to the file shortly after you make them, and at the
latest when Aaron quits.
