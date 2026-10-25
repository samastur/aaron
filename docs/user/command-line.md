# The `aaron` command

`aaron` opens files in Aaron from Terminal or from your own scripts.

```
aaron [--profile NAME] FILE...
aaron --list-profiles
aaron --help
```

- **`aaron FILE...`** opens the files, starting Aaron if needed, and returns
  right away. It does not wait for you to close the window. Every file must
  exist; if one doesn't, `aaron` says which and opens none of them.
- **`--profile NAME`** opens the files with that [profile](profiles.md)
  instead of the default. Case doesn't matter. An unknown name is an error
  that lists the profiles. A file that is already open comes to the front
  and its window switches to the profile.
- **`--list-profiles`** prints the profiles, marking the default.

It exits with status 0 on success, 1 for a missing file, an unknown profile
or when Aaron can't be started, and 2 for wrong usage.

## Installing it

1. Install Aaron in `/Applications` (see [Getting started](getting-started.md#installing)).
2. Open it and choose **Aaron ▸ Install Command Line Tool…**.

This puts `aaron` in `~/.local/bin`, as a link to the copy inside the app,
so it always opens files in the Aaron it was installed from. Aaron then
checks whether `~/.local/bin` is on your `PATH`. If not, it shows the line
to add to `~/.zprofile`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Aaron never installs into Homebrew's folders or anywhere that needs an
administrator password. If `~/.local/bin/aaron` already exists and isn't a
link Aaron made, it is left alone and Aaron tells you.

## Using it from a script

A script that creates a new blog post can open it in Aaron with the blog's
profile. In Python, for example:

```python
import subprocess
subprocess.run(["aaron", "--profile", "Blog", filename], check=True)
```

## Security

Only the `aaron` command can ask Aaron to open files with a chosen profile.
Opening a file runs commands from its profile (preview renderers, the tag
and plugins commands), so the command proves who it is with a random token
that only your user account can read
(`~/Library/Application Support/Aaron/cli-token`). Requests from web pages
or other apps without it are ignored.
