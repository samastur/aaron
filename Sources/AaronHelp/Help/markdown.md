# Markdown help

The **Preview** column says whether Aaron's built-in preview shows the syntax;
**Pelican** refers to Pelican's default Markdown processor (Python-Markdown
with the `extra`, `codehilite` and `meta` extensions). Other tools differ in
details.

## Text

| Write | Get | Preview | Pelican |
|---|---|---|---|
| `*italic*` or `_italic_` | *italic* | yes | yes |
| `**bold**` or `__bold__` | **bold** | yes | yes |
| `***bold italic***` | ***bold italic*** | yes | yes |
| `` `code` `` | `code` | yes | yes |
| `~~struck~~` | ~~struck~~ | yes | no |
| `\*not italic\*` | \*not italic\* | yes | yes |

A paragraph is text separated by an empty line. A line ending with two
spaces or a backslash (`\`) makes a line break inside a paragraph.

## Headings

```
# Heading 1
## Heading 2
### Heading 3 … ###### Heading 6
```

Put a space after the `#` characters. A line of `===` or `---` under text
also makes a level 1 or 2 heading.

## Links and images

```
[link text](https://example.com)
[link text](https://example.com "Title shown on hover")
<https://example.com>
![alt text](images/photo.jpg)
![alt text](images/photo.jpg "Title")

[link text][ref]
[ref]: https://example.com
```

Image and link paths are relative to the document (Aaron's preview) or as
the site generator resolves them (see the Pelican section).

## Lists

```
- item           1. first
- item           2. second
    - nested     3. third
```

Use `-`, `*` or `+` for bullets. Indent nested items by **four spaces**: the
built-in preview accepts two, Pelican needs four. In Pelican, leave an empty
line before a list that follows a paragraph.

Task lists (`- [ ] todo`, `- [x] done`) show in the preview but not in
Pelican.

## Quotes, code and rules

~~~
> A quoted paragraph.
> > A nested quote.

    indented by four spaces: code block

```python
fenced code block with a language
```

---
~~~

A line of `---`, `***` or `___` on its own is a horizontal rule (with an
empty line above it, so it isn't read as a heading underline).

## Tables

```
| Left | Centre | Right |
|:-----|:------:|------:|
| a    |   b    |     c |
```

Supported by both. The colons in the separator line set the alignment.

## Only in Pelican (Python-Markdown `extra`)

| Feature | Syntax |
|---|---|
| Footnotes | `Text[^1].` and on its own line `[^1]: The note.` |
| Definition lists | `Term` on one line, `: Definition` on the next |
| Abbreviations | `*[HTML]: Hyper Text Markup Language` anywhere in the post |
| Attributes | `{: .class #id }` on the line after a paragraph or heading |
| Markdown inside HTML | `<div markdown="1">` … `</div>` |

## HTML

Raw HTML can be used anywhere. Block-level HTML (`<div>`, `<table>`, …) must
start at the beginning of a line with an empty line before it, and Markdown
inside it is not processed (except with `markdown="1"` in Pelican).
