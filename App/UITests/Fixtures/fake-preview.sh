#!/bin/sh
# Fake external preview: wraps the document in a marker page.
printf '<html><body><h1>External renderer</h1><pre>'
cat
printf '</pre></body></html>'
