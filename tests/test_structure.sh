#!/usr/bin/env bash
# tests/test_structure.sh — Verify repository file and directory structure
REPO="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO/tests/helpers.sh"

header "Structure: required root files"
assert_file "$REPO/config.sh"           "config.sh"
assert_file "$REPO/README.md"           "README.md"
assert_file "$REPO/CHANGELOG.md"        "CHANGELOG.md"
assert_file "$REPO/.gitignore"          ".gitignore"
assert_file "$REPO/environment.yml"     "environment.yml"
assert_file "$REPO/0Install.sh"         "0Install.sh"
assert_file "$REPO/1Pipeline.sh"        "1Pipeline.sh (backward compat)"
assert_file "$REPO/2StatPlot.sh"        "2StatPlot.sh (backward compat)"

header "Structure: scripts/ modules"
MODULES=(
    "scripts/02_preprocess.sh"
    "scripts/03_readbased.sh"
    "scripts/04_assembly.sh"
    "scripts/05_binning.sh"
    "scripts/06_isolate_genome.sh"
    "scripts/07_pangenome.sh"
    "scripts/08_appendix.sh"
    "scripts/09_statplot.sh"
)
for m in "${MODULES[@]}"; do
    assert_file "$REPO/$m" "$m"
done

header "Structure: each module sources config.sh"
# 08_appendix.sh is a reference/troubleshooting file — no config needed
SKIP_SOURCE_CHECK=("scripts/08_appendix.sh")
for m in "${MODULES[@]}"; do
    f="$REPO/$m"
    [[ -f "$f" ]] || continue
    skip_it=false
    for s in "${SKIP_SOURCE_CHECK[@]}"; do [[ "$m" == "$s" ]] && skip_it=true; done
    if $skip_it; then
        skip "source config.sh not required: $(basename "$f")"
    elif grep -q 'source.*config\.sh' "$f"; then
        pass "sources config.sh: $(basename "$f")"
    else
        fail "missing 'source config.sh': $(basename "$f")"
    fi
done

header "Structure: each module has ★ MODIFY marker"
for m in "${MODULES[@]}"; do
    f="$REPO/$m"
    [[ -f "$f" ]] || continue
    if grep -q '★' "$f"; then
        pass "has ★ MODIFY marker: $(basename "$f")"
    else
        fail "missing ★ MODIFY marker: $(basename "$f")"
    fi
done

header "Structure: config.sh has all required sections"
assert_contains "$REPO/config.sh" "SECTION 1"        "Section 1 user settings"
assert_contains "$REPO/config.sh" "SECTION 2"        "Section 2 parameters"
assert_contains "$REPO/config.sh" "SECTION 3"        "Section 3 auto-applied"
assert_contains "$REPO/config.sh" "_check_env"       "_check_env function"
assert_contains "$REPO/config.sh" "export.*NPROC"    "export NPROC"
assert_contains "$REPO/config.sh" "MP4_INDEX"        "MP4_INDEX variable"
assert_contains "$REPO/config.sh" "KRAKEN2_DB"       "KRAKEN2_DB variable"

header "Structure: .gitignore covers key patterns"
assert_contains "$REPO/.gitignore" "temp/"            "temp/ ignored"
assert_contains "$REPO/.gitignore" "\.log"            "*.log ignored"
assert_contains "$REPO/.gitignore" "\.bam"            "*.bam ignored"
assert_contains "$REPO/.gitignore" "seq/\*\.fq\.gz\|seq/\*\.fastq" "seq data ignored"

header "Structure: no Mac-specific content in Linux scripts"
MAC_PATTERNS=("Darwin" "gsed" "gawk" "greadlink" "Homebrew" "brew install")
for pat in "${MAC_PATTERNS[@]}"; do
    hits=$(grep -rn "$pat" "$REPO/scripts/" "$REPO/config.sh" 2>/dev/null | grep -v '#' || true)
    if [[ -n "$hits" ]]; then
        fail "Mac-specific content found: '$pat'"
        while IFS= read -r line; do info "$line"; done <<< "$hits"
    else
        pass "No Mac content '$pat'"
    fi
done

summary "Structure Tests"
