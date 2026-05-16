#!/usr/bin/env bash
# test_project/run_test.sh — Dry-run / smoke-test for the EasyMetagenome pipeline
#
# This script does NOT execute any bioinformatics tools.
# It checks that:
#   1. The directory structure is correct
#   2. FASTQ files are present for all samples in metadata
#   3. config.test.sh exports all required variables
#   4. Each pipeline module can be syntax-checked
#
# Usage (from repo root):
#   bash test_project/run_test.sh

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"

PASS=0; FAIL=0; SKIP=0
ok()   { echo "  ✔  $*"; PASS=$((PASS+1)); }
err()  { echo "  ✘  $*"; FAIL=$((FAIL+1)); }
skip() { echo "  –  $* (skipped)"; SKIP=$((SKIP+1)); }

echo ""
echo "══════════════════════════════════════════════"
echo "  EasyMetagenome — Test Project Smoke-Test"
echo "══════════════════════════════════════════════"

# ── 1. Directory structure ─────────────────────────────────────────────────────
echo ""
echo "▶ Directory structure"
for d in seq temp result; do
    [[ -d "$HERE/$d" ]] && ok "$d/ exists" || err "$d/ missing"
done

# ── 2. Metadata file ───────────────────────────────────────────────────────────
echo ""
echo "▶ Metadata"
meta="$HERE/result/metadata.txt"
if [[ -f "$meta" ]]; then
    ok "metadata.txt found"
    sample_count=$(tail -n +2 "$meta" | wc -l)
    ok "$sample_count samples defined in metadata.txt"
else
    err "result/metadata.txt not found"
fi

# ── 3. FASTQ presence ──────────────────────────────────────────────────────────
echo ""
echo "▶ FASTQ files"
if [[ -f "$meta" ]]; then
    missing_fq=0
    while IFS=$'\t' read -r sid _rest; do
        [[ "$sid" == "SampleID" ]] && continue
        f1="$HERE/seq/${sid}_1.fq.gz"
        f2="$HERE/seq/${sid}_2.fq.gz"
        if [[ -f "$f1" && -f "$f2" ]]; then
            ok "FASTQ pair found: ${sid}"
        else
            skip "FASTQ pair missing: ${sid} — add files to seq/ before running pipeline"
            ((missing_fq++))
        fi
    done < "$meta"
    [[ $missing_fq -eq 0 ]] && ok "All FASTQ pairs present" || true
fi

# ── 4. config.test.sh variables ───────────────────────────────────────────────
echo ""
echo "▶ config.test.sh"
if [[ -f "$HERE/config.test.sh" ]]; then
    source "$HERE/config.test.sh" 2>/dev/null
    REQUIRED=(soft db wd NPROC NJOB GROUP_COL READ_LEN MP4_INDEX KRAKEN2_DB BIN_COMP BIN_CONT BRACKEN_PROP)
    for v in "${REQUIRED[@]}"; do
        val="${!v:-}"
        [[ -n "$val" ]] && ok "\$$v = $val" || err "\$$v is not set"
    done
else
    err "config.test.sh not found"
fi

# ── 5. Syntax check on all modules ────────────────────────────────────────────
echo ""
echo "▶ Module syntax"
for f in "$REPO"/scripts/*.sh; do
    name="$(basename "$f")"
    if bash -n "$f" 2>/dev/null; then
        ok "syntax OK: $name"
    else
        err "syntax error: $name"
    fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
echo "  TOTAL: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "══════════════════════════════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
