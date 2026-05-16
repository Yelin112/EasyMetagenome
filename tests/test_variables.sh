#!/usr/bin/env bash
# tests/test_variables.sh — Cross-check: every config variable used in scripts
#                           is also defined (exported) in config.sh
REPO="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO/tests/helpers.sh"

# Variables exported by config.sh
EXPORTED=(soft db wd NPROC NJOB GROUP_COL READ_LEN MP4_INDEX KRAKEN2_DB BIN_COMP BIN_CONT BRACKEN_PROP)

# Variables that are intentionally local to scripts (not from config.sh)
LOCAL_VARS=(i j n m g h c x p s e f t
    alpha_diversity dis compare path pcl readLen type prop sd
    BASENAME output_dir prefix genomeID friendlyName sample_name
    LD_LIBRARY_PATH tax readLen bam_dir bam_output fastq1 fastq2
    taxon taxDir taxa assemblyFile input_dir filename deflineName)

header "Variable Coverage: config vars used in scripts"
for v in "${EXPORTED[@]}"; do
    pattern="\${${v}}"
    files_using=()
    for f in "$REPO"/scripts/*.sh; do
        grep -q "$pattern" "$f" 2>/dev/null && files_using+=("$(basename "$f")")
    done
    if [[ ${#files_using[@]} -gt 0 ]]; then
        pass "\$$v used in: ${files_using[*]}"
    else
        skip "\$$v defined in config.sh but not referenced in scripts/"
    fi
done

header "Variable Coverage: scripts use only known variables"
# Extract all ${VAR} from scripts — strip filename prefix that grep -oh adds
mapfile -t used_vars < <(
    grep -oh '\${[a-zA-Z_][a-zA-Z_0-9]*}' "$REPO"/scripts/*.sh \
    | grep -o '\${[a-zA-Z_][a-zA-Z_0-9]*}' \
    | sed 's/\${//;s/}//' | sort -u
)

for v in "${used_vars[@]}"; do
    # Skip single-char loop vars and known locals
    if [[ ${#v} -le 1 ]]; then continue; fi
    in_exported=false; in_local=false
    for e in "${EXPORTED[@]}"; do [[ "$v" == "$e" ]] && in_exported=true && break; done
    for l in "${LOCAL_VARS[@]}"; do [[ "$v" == "$l" ]] && in_local=true && break; done
    if $in_exported; then
        : # already tested above
    elif $in_local; then
        : # known local var, skip silently
    else
        fail "Unknown var \$$v used in scripts but not in config.sh or known locals"
    fi
done
pass "All script variables are either config-sourced or local"

header "Variable Coverage: no hard-coded thread counts remain"
# Check for hard-coded values that should use variables.
# rush -j 1 is intentionally sequential (e.g. mpa merge), so it is excluded.
PATTERNS=("--threads [2-9]" "--cpu [2-9]" "--cpus [2-9]" "rush -j [2-9]" "-p [0-9][0-9]")
found_any=false
for pat in "${PATTERNS[@]}"; do
    hits=$(grep -rn "$pat" "$REPO/scripts/" 2>/dev/null | grep -v '^\s*#' | grep -v 'NPROC\|NJOB' || true)
    if [[ -n "$hits" ]]; then
        fail "Hard-coded value found (pattern: '$pat')"
        while IFS= read -r line; do info "$line"; done <<< "$hits"
        found_any=true
    fi
done
$found_any || pass "No remaining hard-coded thread/job counts (rush -j 1 is allowed as intentional)"

summary "Variable Coverage Tests"
