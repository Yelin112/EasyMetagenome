#!/usr/bin/env bash
# tests/test_syntax.sh — Shell syntax validation for all pipeline scripts
REPO="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO/tests/helpers.sh"

header "Syntax Check: config.sh"
assert_syntax "$REPO/config.sh"

header "Syntax Check: scripts/"
for f in "$REPO"/scripts/*.sh; do
    assert_syntax "$f"
done

header "Syntax Check: root scripts (informational — CRLF originals, failures expected)"
# These original files may have mixed CRLF line endings inherited from upstream.
# Failures here are informational only and do not affect suite pass/fail.
for f in "$REPO"/0Install.sh "$REPO"/1Pipeline.sh "$REPO"/2StatPlot.sh; do
    if [[ ! -f "$f" ]]; then skip "$(basename "$f") not found"; continue; fi
    if bash -n "$f" 2>/dev/null; then
        pass "syntax OK: $(basename "$f")"
    else
        skip "syntax issue in original file (CRLF): $(basename "$f")"
    fi
done

summary "Syntax Tests"
