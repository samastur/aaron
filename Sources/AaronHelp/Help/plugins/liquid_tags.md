Embeds media and files with `{% … %}` tags. Each tag must be enabled in the
`LIQUID_TAGS` setting. Common ones:

```
{% img [class] /images/photo.jpg [width [height]] ["title" ["alt"]] %}
{% youtube VIDEO_ID [width height] %}
{% vimeo VIDEO_ID [width height] %}
{% video /videos/clip.mp4 [width height] [/images/poster.jpg] %}
{% include_code example.py [lang:python] [Title] %}
{% notebook notebook.ipynb %}
```

Parts in brackets are optional.
