# Pelican

## Metadata

The post starts with `Key: value` lines, followed by an empty line.

```
Title: My post
Date: 2026-10-24 10:00
Modified: 2026-10-25 09:00
Category: Writing
Tags: writing, blogging
Slug: my-post
Authors: Jane Doe
Summary: One or two sentences shown in lists and feeds.
Status: draft
```

| Field | Meaning |
|---|---|
| `Title` | Required. |
| `Date` | Publication date; `YYYY-MM-DD` or `YYYY-MM-DD HH:MM`. Required unless the site sets a default. |
| `Modified` | Date of the last significant change. |
| `Category` | One category; by default the folder the post is in. |
| `Tags` | Comma-separated; tags may contain spaces. |
| `Slug` | Used in the URL; by default made from the title. |
| `Author` / `Authors` | One author / a comma-separated list. |
| `Summary` | Replaces the automatic summary (the start of the post). |
| `Status` | `published` (default), `draft` (built but not listed) or `hidden`. |
| `Lang`, `Translation` | Language code, and `true` for a translation of another post. |
| `Template` | Template to render this post with instead of `article`. |
| `Save_as`, `URL` | Output path and URL of this post. |

## Links to other content

Pelican rewrites these when it builds the site:

| Write | Links to |
|---|---|
| `[text]({filename}/2015-review.md)` | another post or page; the path is relative to the content folder when it starts with `/`, otherwise to this post |
| `![alt]({static}/images/photo.jpg)` | a static file, as it is copied to the output |
| `![alt]({attach}photo.jpg)` | a file next to this post, copied next to the post's output |
| `[text]({tag}python)` | a tag page |
| `[text]({category}writing)` | a category page |
| `[text]({author}jane-doe)` | an author page |
| `[text]({index})` | the site's index page |

Aaron's built-in preview does not resolve these; use a Pelican renderer for
an exact preview.

## Code highlighting

Fenced code with a language is highlighted by Pygments:

~~~
```python
print("hello")
```
~~~

In an indented code block, a first line `:::python` sets the language.
