#!/usr/bin/env bash
# tests/helpers.sh — shared test utilities
# Source this file in each test script: source "$(dirname "$0")/helpers.sh"

# ── Counters ──────────────────────────────────────────────────────────────────
_PASS=0; _FAIL=0; _SKIP=0

# ── Colors (disabled when not a terminal) ─────────────────────────────────────
if [[ -t 1 ]]; then
    _GREEN='\033[0;32m'; _RED='\033[0;31m'; _YELLOW='\033[0;33m'
    _CYAN='\033[0;36m';  _BOLD='\033[1m';   _RESET='\033[0m'
else
    _GREEN=''; _RED=''; _YELLOW=''; _CYAN=''; _BOLD=''; _RESET=''
fi

# ── Output helpers ────────────────────────────────────────────────────────────
header()  { echo -e "\n${_BOLD}${_CYAN}══ $* ══${_RESET}"; }
pass()    { echo -e "  ${_GREEN}✔${_RESET}  $*"; ((_PASS++)); }
fail()    { echo -e "  ${_RED}✘${_RESET}  $*"; ((_FAIL++)); }
skip()    { echo -e "  ${_YELLOW}–${_RESET}  $* (skipped)"; ((_SKIP++)); }
info()    { echo -e "     ${_YELLOW}↳${_RESET}  $*"; }

# ── Assertion helpers ─────────────────────────────────────────────────────────

# assert_syntax FILE — bash -n check
assert_syntax() {
    local f="$1"
    if bash -n "$f" 2>/dev/null; then
        pass "syntax OK: $(basename "$f")"
    else
        fail "syntax FAIL: $(basename "$f")"
        info "$(bash -n "$f" 2>&1 | head -3)"
    fi
}

# assert_file FILE — file exists and is non-empty
assert_file() {
    local f="$1" label="${2:-$1}"
    if [[ -s "$f" ]]; then
        pass "file exists: $label"
    elif [[ -f "$f" ]]; then
        fail "file empty: $label"
    else
        fail "file missing: $label"
    fi
}

# assert_dir DIR — directory exists
assert_dir() {
    local d="$1" label="${2:-$1}"
    if [[ -d "$d" ]]; then
        pass "dir exists: $label"
    else
        fail "dir missing: $label"
    fi
}

# assert_var VAR_NAME — variable is exported and non-empty (after sourcing config)
assert_var() {
    local name="$1"
    local val="${!name}"
    if [[ -n "$val" ]]; then
        pass "config var \$$name = $val"
    else
        fail "config var \$$name is unset or empty"
    fi
}

# assert_contains FILE PATTERN — file contains a string/pattern
assert_contains() {
    local f="$1" pattern="$2" label="${3:-$pattern}"
    if grep -q "$pattern" "$f" 2>/dev/null; then
        pass "contains '$label': $(basename "$f")"
    else
        fail "missing '$label': $(basename "$f")"
    fi
}

# ── Summary (call at end of each test script) ─────────────────────────────────
summary() {
    local suite="${1:-Tests}"
    echo ""
    echo -e "${_BOLD}$suite: ${_GREEN}${_PASS} passed${_RESET}, ${_RED}${_FAIL} failed${_RESET}, ${_YELLOW}${_SKIP} skipped${_RESET}"
    [[ $_FAIL -eq 0 ]]   # exit 0 if all passed
}
