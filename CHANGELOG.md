# Changelog / 更新日志

All notable changes to EasyMetagenome are documented here.
详细记录 EasyMetagenome 的所有重要变更。

Format: [Version] Date — Summary
格式：[版本] 日期 — 摘要

---

## [1.24] 2025-11-22

### Added / 新增
- `config.sh`: Unified configuration entry point; all pipeline scripts source this file.
  统一配置文件；所有流程脚本通过此文件读取环境变量。
- `scripts/` directory: `1Pipeline.sh` split into eight focused modules (02–08) for easier
  independent execution and maintenance.
  `scripts/` 目录：将 `1Pipeline.sh` 拆分为8个独立模块（02–08），便于单独运行和维护。
- `scripts/09_statplot.sh`: Merged Linux and macOS visualization scripts into one file with
  automatic platform detection.
  合并Linux和macOS可视化脚本为一个文件，自动检测平台。
- Platform detection in `config.sh`: sets `$SED`, `$AWK`, `$READLINK` for Linux/macOS compatibility.
  `config.sh` 中新增平台检测，自动设置 `$SED`、`$AWK`、`$READLINK` 以兼容Linux/macOS。

### Changed / 变更
- `.gitignore`: Added rules for sequencing data, intermediate files, logs, and `result12/`.
  补充了测序数据、中间文件、日志及 `result12/` 的忽略规则。

### Unchanged / 未变更
- `0Install.sh`, `1Pipeline.sh`, `2StatPlot.sh`, `2StatPlot_mac.sh`: retained as-is for
  backward compatibility.
  保留原有脚本不变，确保向后兼容。

---

## [1.23] 2025-06-01

- HUMAnN4 support added (添加HUMAnN4支持)
- MetaPhlAn4 updated (MetaPhlAn4升级)

---

## [1.22] 2024-12-01

- Added Kraken2+Bracken diversity visualization (新增Kraken2+Bracken多样性可视化)
- Added CoverM genome quantification module (新增CoverM基因组定量模块)

---

## [1.21] 2024-06-01

- Added GTDB-tk v2 support (支持GTDB-tk v2)
- Added dRep strain-level clustering (新增dRep株水平聚类)

---

*Older versions archived in `appendix/history/`.*
*更早版本归档于 `appendix/history/`。*
