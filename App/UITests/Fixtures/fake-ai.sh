#!/bin/sh
# Fake AI provider for UI tests: checks that the prompt contains the
# document and answers with fixed suggestions.
prompt=$(cat)
case "$prompt" in
  *"<document>"*"teh quick"*) ;;
  *) echo "prompt did not contain the document" >&2; exit 1 ;;
esac
sleep 1
cat <<'JSON'
Here are my suggestions:
```json
{"suggestions": [
  {"original": "teh", "prefix": "The cat saw ", "suffix": " quick", "replacement": "the", "message": "Spelling mistake.", "category": "spelling"},
  {"original": "jumped over", "prefix": "", "suffix": "", "replacement": null, "message": "Consider a stronger verb.", "category": "style"},
  {"original": "nonexistent words", "replacement": "x", "message": "This quote is not in the text.", "category": "grammar"}
]}
```
JSON
