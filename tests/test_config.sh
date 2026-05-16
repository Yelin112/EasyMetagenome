#!/usr/bin/env bash
# tests/test_config.sh — Verify config.sh structure and variable exports
REPO="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO/tests/helpers.sh"

# ── Source config.sh in a subshell to capture its exports ─────────────────────
header "Config: source and export check"

# Temporarily set dummy paths so _check_env doesn't warn
_config_out=$(
    soft=/tmp db=/tmp wd=/tmp \
    bash -c "source $REPO/config.sh 2>&1; echo '__VARS__'; export -p" 2>&1
)

# Check _check_env output: should NOT contain ERROR
if echo "$_config_out" | grep -q '\[config\]'; then
    pass "_check_env() ran (output visible)"
else
    fail "_check_env() produced no output — may have been removed"
fi

# Source for real to test variable export
source "$REPO/config.sh" 2>/dev/null || true

header "Config: required variables defined"
CONFIG_VARS=(
    soft db wd
    NPROC NJOB GROUP_COL READ_LEN
    MP4_INDEX KRAKEN2_DB
    BIN_COMP BIN_CONT BRACKEN_PROP
)
for v in "${CONFIG_VARS[@]}"; do
    assert_var "$v"
done

header "Config: variable types / value sanity"

# NPROC and NJOB must be integers > 0
if [[ "$NPROC" =~ ^[1-9][0-9]*$ ]]; then
    pass "NPROC is a positive integer ($NPROC)"
else
    fail "NPROC is not a positive integer: '$NPROC'"
fi

if [[ "$NJOB" =~ ^[1-9][0-9]*$ ]]; then
    pass "NJOB is a positive integer ($NJOB)"
else
    fail "NJOB is not a positive integer: '$NJOB'"
fi

# GROUP_COL must be integer >= 1
if [[ "$GROUP_COL" =~ ^[1-9][0-9]*$ ]]; then
    pass "GROUP_COL is a valid column index ($GROUP_COL)"
else
    fail "GROUP_COL is not a valid column index: '$GROUP_COL'"
fi

# READ_LEN common values: 75, 100, 150, 250
if [[ "$READ_LEN" =~ ^[0-9]+$ ]] && (( READ_LEN >= 50 && READ_LEN <= 300 )); then
    pass "READ_LEN is in reasonable range ($READ_LEN bp)"
else
    fail "READ_LEN looks unusual: '$READ_LEN' (expected 50-300)"
fi

# BIN_COMP and BIN_CONT must be 0-100
if [[ "$BIN_COMP" =~ ^[0-9]+$ ]] && (( BIN_COMP >= 0 && BIN_COMP <= 100 )); then
    pass "BIN_COMP is a valid percentage ($BIN_COMP%)"
else
    fail "BIN_COMP out of range: '$BIN_COMP'"
fi

if [[ "$BIN_CONT" =~ ^[0-9]+$ ]] && (( BIN_CONT >= 0 && BIN_CONT <= 100 )); then
    pass "BIN_CONT is a valid percentage ($BIN_CONT%)"
else
    fail "BIN_CONT out of range: '$BIN_CONT'"
fi

# BRACKEN_PROP must be 0 < x <= 1
if [[ "$BRACKEN_PROP" =~ ^0\.[0-9]+$|^1\.0*$ ]]; then
    pass "BRACKEN_PROP is a valid proportion ($BRACKEN_PROP)"
else
    fail "BRACKEN_PROP should be a decimal between 0 and 1: '$BRACKEN_PROP'"
fi

header "Config: PATH includes EasyMicrobiome"
if echo "$PATH" | grep -q 'EasyMicrobiome'; then
    pass "PATH contains EasyMicrobiome paths"
else
    # db may not exist in test environment; warn only
    skip "PATH EasyMicrobiome check (db=${db} may not exist yet)"
fi

summary "Config Tests"
