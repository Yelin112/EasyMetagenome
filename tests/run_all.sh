#!/usr/bin/env bash
# tests/run_all.sh — Master test runner
# Usage:
#   bash tests/run_all.sh           # run all tests
#   bash tests/run_all.sh syntax    # run only test_syntax.sh
#   bash tests/run_all.sh config    # run only test_config.sh
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$REPO/tests"

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    BOLD='\033[1m'; RED='\033[0;31m'; GREEN='\033[0;32m'
    YELLOW='\033[0;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
else
    BOLD=''; RED=''; GREEN=''; YELLOW=''; CYAN=''; RESET=''
fi

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════╗"
echo "║      EasyMetagenome Test Suite               ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${RESET}"

# ── Test suite registry ───────────────────────────────────────────────────────
declare -A SUITES=(
    [syntax]="test_syntax.sh"
    [config]="test_config.sh"
    [variables]="test_variables.sh"
    [structure]="test_structure.sh"
)

if [[ $# -gt 0 ]]; then
    RUN_SUITES=("$@")
else
    RUN_SUITES=(syntax config variables structure)
fi

# ── Run each suite, streaming output directly ─────────────────────────────────
FAILED_SUITES=()
TMPDIR_RESULTS=$(mktemp -d)

for suite in "${RUN_SUITES[@]}"; do
    script="${SUITES[$suite]:-}"
    if [[ -z "$script" ]]; then
        echo -e "${YELLOW}WARNING: unknown suite '$suite', skipping${RESET}"
        continue
    fi
    filepath="$TESTS_DIR/$script"
    if [[ ! -f "$filepath" ]]; then
        echo -e "${RED}ERROR: $filepath not found${RESET}"
        continue
    fi

    echo -e "${BOLD}▶ Running: ${suite}${RESET}"
    result_file="$TMPDIR_RESULTS/${suite}.txt"

    # Stream output to terminal AND capture to file
    bash "$filepath" 2>&1 | tee "$result_file"
    exit_code=${PIPESTATUS[0]}

    [[ $exit_code -ne 0 ]] && FAILED_SUITES+=("$suite")
    echo ""
done

# ── Aggregate counts from result files ───────────────────────────────────────
TOTAL_PASS=0; TOTAL_FAIL=0; TOTAL_SKIP=0
for f in "$TMPDIR_RESULTS"/*.txt; do
    [[ -f "$f" ]] || continue
    p=$(grep -c '✔' "$f" 2>/dev/null); p=${p:-0}
    fa=$(grep -c '✘' "$f" 2>/dev/null); fa=${fa:-0}
    s=$(grep -c 'skipped' "$f" 2>/dev/null); s=${s:-0}
    TOTAL_PASS=$(( TOTAL_PASS + p ))
    TOTAL_FAIL=$(( TOTAL_FAIL + fa ))
    TOTAL_SKIP=$(( TOTAL_SKIP + s ))
done
rm -rf "$TMPDIR_RESULTS"

# ── Final summary ─────────────────────────────────────────────────────────────
echo -e "${BOLD}══════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  TOTAL: ${GREEN}${TOTAL_PASS} passed${RESET}, ${RED}${TOTAL_FAIL} failed${RESET}, ${YELLOW}${TOTAL_SKIP} skipped${RESET}"

if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
    echo -e "  ${RED}Failed suites: ${FAILED_SUITES[*]}${RESET}"
    echo -e "${BOLD}══════════════════════════════════════════════${RESET}"
    exit 1
else
    echo -e "  ${GREEN}All suites passed.${RESET}"
    echo -e "${BOLD}══════════════════════════════════════════════${RESET}"
    exit 0
fi
