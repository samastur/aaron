# Aaron

A native macOS Markdown editor for writing blog posts, with:

- **Live preview** in a side panel, rendered by a built-in Markdown renderer
  or by your own tools (for example your blog's real Pelican theme).
- **AI review**: configurable AI actions (grammar, fact checking, style, …)
  that produce suggestions you accept or dismiss one by one. Runs on
  your existing Claude Code or Codex subscription through their command-line
  tools.
- **Pelican support**: metadata awareness, tag autocompletion from a
  configurable tag source, and a new-post template.

Nothing is tied to a particular blog or folder layout; every tool and path is
configuration. Requires macOS 26 or later.

## Documentation

- [User guide](docs/user/README.md)
- [Developer guide](docs/developer/development.md), [design](docs/developer/design.md), [testing](docs/developer/testing.md)
- [Decisions made for the first version](docs/decisions.md)

## Quick start

```sh
brew install xcodegen
cd App && xcodegen generate
xcodebuild -project Aaron.xcodeproj -scheme Aaron -derivedDataPath ../build/DerivedData build
open ../build/DerivedData/Build/Products/Debug/Aaron.app
```

Tests: `swift test`, `scripts/smoke-test.sh`, and
`xcodebuild … test` in `App/` (see [testing](docs/developer/testing.md)).
