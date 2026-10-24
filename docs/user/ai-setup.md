# Setting up AI actions and providers

Aaron does not talk to AI services directly. It runs a command-line tool, a
**provider**, that you have installed and logged in to, and sends it a prompt.
This way your existing Claude or ChatGPT subscription is used, and no API
keys are stored in Aaron.

An **action** is a named prompt ("Grammar and spelling") plus the provider
that runs it. Both are configured in **Settings ▸ AI**, under the
**Actions** and **Providers** tabs.

## Providers

A provider is a shell command that reads the prompt on **standard input**
and prints the AI's answer on **standard output**. It runs in `zsh` as a
login shell, in the document's folder (your home folder for unsaved
documents). The folders `~/.local/bin`, `/opt/homebrew/bin` and
`/usr/local/bin` are added to `PATH`, so tools installed there are found
even when Aaron is started from the Finder.

| Field | Meaning |
|---|---|
| **Name** | Shown when choosing a provider for an action. |
| **Command** | The shell command. |
| **Timeout** | Seconds before the command is stopped (default 300). |

### Default providers

| Name | Command | Notes |
|---|---|---|
| Claude | `claude -p --tools "" --no-session-persistence` | Claude Code in non-interactive mode, with all tools turned off: fast, and it cannot read or change files. Sessions are not saved to your Claude history. |
| Claude (web) | `claude -p --tools "WebSearch,WebFetch" --allowedTools "WebSearch,WebFetch" --no-session-persistence` | Like Claude, but may search the web. Used by *Fact check*. Slower. |
| Codex | `codex exec --skip-git-repo-check --ephemeral --sandbox read-only -` | OpenAI Codex in non-interactive mode with a read-only sandbox; `-` reads the prompt from standard input. |

Both tools must be installed and logged in once in Terminal (`claude`, then
follow the login; `codex login`).

Useful variations:

- Choose a model: `claude -p --model opus --tools ""` or
  `codex exec -m gpt-5 --skip-git-repo-check --sandbox read-only -`.
- Any other tool works if it reads a prompt on standard input and prints the
  answer, for example a local model through `ollama run llama3`.

## Actions

| Field | Meaning |
|---|---|
| **Name** | Shown in the menus. |
| **Provider** | Which provider runs it. If its provider is deleted, the action shows *Missing provider* and running it reports an error. |
| **Prompt** | What the AI should look for. |

Use **+** and **−** below the list to add and remove actions, and the arrows
to reorder them. The order is used in all menus, and the first nine actions
get the shortcuts ⌥⌘1 to ⌥⌘9.

### Writing a prompt

Only describe *what to look for*. Aaron adds the rest itself: that the text
is a Markdown document, the exact answer format, the selection (if any) and
the document. Tips:

- Say what to ignore ("Ignore Markdown syntax, code and URLs").
- Ask for few, valuable suggestions if you get too many trivial ones.
- Ask for comments rather than replacements when you want to rewrite
  yourself ("Point out unclear passages; don't propose replacements").
- Mention the audience or style guide ("British English", "for developers").

### Default actions

- **Grammar and spelling** (Claude): spelling, grammar, punctuation and
  typos, without stylistic rewrites.
- **Fact check** (Claude (web)): names, dates, numbers, technical statements
  and quotes that are wrong, outdated or doubtful.
- **Style** (Claude): clarity, flow and concision, preserving your voice.

## The answer format

For reference, and for writing your own provider scripts: the AI is asked to
answer with JSON only.

```json
{"suggestions": [
  {
    "original": "exact text from the document",
    "prefix": "text immediately before it",
    "suffix": "text immediately after it",
    "replacement": "new text, or null for a comment",
    "message": "explanation for the author",
    "category": "grammar"
  }
]}
```

Only `original` is required. Aaron also accepts the JSON inside a
```` ```json ```` fence or surrounded by other text, a bare list of
suggestions, and Claude Code's `--output-format json` wrapper. The AI never
reports positions: Aaron finds each `original` in the text itself, as
described in [AI review](review.md#suggestions-that-could-not-be-placed).
