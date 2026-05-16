# test_project/ — Standalone local test workspace

This directory is a self-contained workspace for validating the EasyMetagenome
pipeline on a local server before running it on real data.

## Directory layout

```
test_project/
├── config.test.sh       # Test-specific config (low NPROC/NJOB, local wd)
├── run_test.sh          # Smoke-test: checks structure, FASTQs, config, syntax
├── result/
│   └── metadata.txt     # 4 test samples (Y1 Y2 C1 C2), edit as needed
├── seq/
│   ├── README.md        # Instructions for downloading / generating test FASTQs
│   ├── Y1_1.fq.gz  ←── add these yourself (see seq/README.md)
│   ├── Y1_2.fq.gz
│   └── ...
└── temp/                # Pipeline writes intermediate files here (auto-created)
```

## Quick start

```bash
# 1. From the repo root, run the smoke-test (no bioinformatics tools needed)
bash test_project/run_test.sh

# 2. Add FASTQ files (see seq/README.md), then source the test config
source test_project/config.test.sh

# 3. Run individual pipeline modules against this test workspace
bash scripts/02_preprocess.sh
bash scripts/03_readbased.sh
# ...
```

## Editing metadata

`result/metadata.txt` is a tab-separated file.  Column 3 (`Description`) is
used as the group label by default (`GROUP_COL=3`).  To change the grouping
column, edit `config.test.sh` → `GROUP_COL=<column number>`.

| SampleID | Group | Description |
|----------|-------|-------------|
| Y1 | Young | Young healthy volunteer 1 |
| Y2 | Young | Young healthy volunteer 2 |
| C1 | Control | Control sample 1 |
| C2 | Control | Control sample 2 |
