#!/bin/zsh
# Renders App/Icon/aaron.svg into the app icon's PNGs (needs rsvg-convert,
# from `brew install librsvg`). Run after changing the SVG; the PNGs are
# committed so building doesn't depend on the tool or on installed fonts.
set -eu
ROOT=${0:A:h:h}
SVG=$ROOT/App/Icon/aaron.svg
SET=$ROOT/App/Sources/Aaron/Assets.xcassets/AppIcon.appiconset
mkdir -p $SET
for size in 16 32 64 128 256 512 1024; do
  rsvg-convert -w $size -h $size $SVG -o $SET/icon_$size.png
done
cat > $SET/Contents.json <<'JSON'
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16", "filename" : "icon_16.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16", "filename" : "icon_32.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32", "filename" : "icon_32.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32", "filename" : "icon_64.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_256.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_512.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_1024.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
print '{ "info" : { "author" : "xcode", "version" : 1 } }' > $SET/../Contents.json
print "Wrote $SET"
