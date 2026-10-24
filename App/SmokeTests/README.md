# Smoke tests

End-to-end checks of the real app that need no macOS automation
permissions. Each `*.json` file is a step script for the Debug build's
harness (`App/Sources/Aaron/DebugHarness.swift`); `config.json` is the
configuration used for all of them (`$FIXTURES` is replaced with
`App/UITests/Fixtures`). Run them with `scripts/smoke-test.sh`.
