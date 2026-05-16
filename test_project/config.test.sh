#!/usr/bin/env bash
# test_project/config.test.sh — Minimal settings for local pipeline testing
# Usage: source test_project/config.test.sh
#        (overrides config.sh for a lightweight test run)

# ── Paths ─────────────────────────────────────────────────────────────────────
soft=~/miniconda3                       # conda root (adjust if needed)
db=~/db                                 # database root
wd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # this test_project/ dir

# ── Compute resources (reduced for testing) ───────────────────────────────────
NPROC=2          # threads per job
NJOB=1           # parallel jobs (keep low to avoid OOM on a laptop/dev node)

# ── Analysis parameters ───────────────────────────────────────────────────────
GROUP_COL=3      # metadata column that holds the group label
READ_LEN=150     # read length of test FASTQ files

MP4_INDEX=mpa_vOct22_CHOCOPhlAnSGB_202403
KRAKEN2_DB=pluspf16g

BIN_COMP=50      # minimum bin completeness %
BIN_CONT=10      # maximum bin contamination %
BRACKEN_PROP=0.2 # minimum fraction of reads to report a taxon

export soft db wd NPROC NJOB GROUP_COL READ_LEN \
       MP4_INDEX KRAKEN2_DB BIN_COMP BIN_CONT BRACKEN_PROP

echo "[config.test] wd=${wd}  NPROC=${NPROC}  NJOB=${NJOB}"
