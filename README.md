# EasyMetagenome 易宏基因组

**A user-friendly and flexible pipeline for shotgun metagenomic analysis**
**简单易用的宏基因组鸟枪法测序分析流程**

[![Version](https://img.shields.io/badge/version-v1.24-blue)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)](https://www.linux.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

> **Citation / 引文**
> Bai, Defeng, Tong Chen, ..., Yong-Xin Liu. 2025. "EasyMetagenome: A User-Friendly and Flexible Pipeline for Shotgun Metagenomic Analysis in Microbiome Research." **iMeta** 4: e70001. <https://doi.org/10.1002/imt2.70001> (Highly Cited / 高被引)

![Pipeline Overview](https://github.com/baidefeng/EasyMetagenome/blob/master/result/EasyMetagenomePipeline2.jpg)

---

## 目录 Table of Contents

- [项目简介](#项目简介)
- [快速开始](#快速开始)
- [目录结构](#目录结构)
- [分析模块](#分析模块)
- [环境要求](#环境要求)
- [数据库需求](#数据库需求)
- [常见问题](#常见问题)
- [引用](#引用)

---

## 项目简介

EasyMetagenome 提供从原始测序数据到物种和功能组成表的完整宏基因组分析流程，分为四个主要步骤：

| 步骤 | 内容 |
|------|------|
| **1. 数据预处理** | Fastp 质量控制 + KneadData 去宿主 |
| **2. 基于读长分析** | HUMAnN4 物种功能组成 / Kraken2+Bracken 物种注释 |
| **3. 组装分析** | MEGAHIT 组装 → 基因预测 → 功能注释 |
| **4. 分箱分析** | MetaWRAP 分箱 → dRep 去冗余 → GTDB-tk 注释 |

**特点 Features**
- 所有参数集中在一个文件 `config.sh`，修改一处全流程生效
- 脚本按功能模块拆分，可单独执行任意步骤
- 中英文双语注释，每个命令均有说明

---

## 快速开始

### 第一步：获取代码

```bash
# 从 GitHub 克隆
git clone https://github.com/yelin112/EasyMetagenome.git
cd EasyMetagenome
```

### 第二步：配置环境变量（唯一必改文件）

```bash
vi config.sh
```

将以下变量改为你服务器的实际路径：

```bash
soft=~/miniconda3       # conda 安装目录，运行 `conda env list` 确认
db=~/db                 # 数据库存放目录
wd=~/meta               # 本次项目的工作目录
NPROC=8                 # CPU 线程数（建议 8–32）
NJOB=2                  # 并行样本数（NPROC × NJOB ≤ 服务器总核数）
KRAKEN2_DB=pluspf16g    # Kraken2 数据库类型，按服务器内存选择
```

验证配置是否正确：

```bash
source config.sh
# 输出示例: [config] Environment OK: soft=~/miniconda3 db=~/db wd=~/meta NPROC=8 NJOB=2
```

### 第三步：安装软件和数据库

参照 `0Install.sh` 按模块安装（首次约需 1–3 天）：

```bash
# 推荐最小安装（质控 + Kraken2 物种注释）
# 1. 安装 kneaddata 环境
conda create -n kneaddata && conda activate kneaddata
conda install -c biobakery kneaddata

# 2. 安装 kraken2 环境
conda create -n kraken2 && conda activate kraken2
conda install -c bioconda kraken2 bracken

# 3. 下载去宿主数据库（人类基因组，3.6 GB）
kneaddata_database --download human_genome bowtie2 ${db}/kneaddata/human

# 4. 下载 Kraken2 数据库（16 GB，小内存服务器选此）
mkdir -p ${db}/kraken2/pluspf16g
wget -c ftp://download.nmdc.cn/tools/meta/kraken2/k2_pluspf_16_GB_20240605.tar.gz
tar xvzf k2_pluspf_16_GB_20240605.tar.gz -C ${db}/kraken2/pluspf16g
```

### 第四步：准备测试数据

```bash
mkdir -p ~/meta && cd ~/meta
mkdir -p seq temp result

# 下载元数据
wget -c http://www.imeta.science/github/EasyMetagenome/result/metadata.txt -O result/metadata.txt

# 下载测试序列（6个样本，共约 1 GB）
cd seq
awk '{system("wget -c http://www.imeta.science/github/EasyMetagenome/seq/"$1"_1.fq.gz")}' \
    <(tail -n+2 ../result/metadata.txt)
awk '{system("wget -c http://www.imeta.science/github/EasyMetagenome/seq/"$1"_2.fq.gz")}' \
    <(tail -n+2 ../result/metadata.txt)
cd ..
```

### 第五步：运行分析

脚本设计为**交互式逐步执行**，用编辑器打开对应模块脚本，逐节复制命令到终端运行：

```bash
# 推荐最小测试路径（1-2 天完成）
# 打开脚本，按节逐步执行
vi scripts/02_preprocess.sh    # 质控 + 去宿主
vi scripts/03_readbased.sh     # Kraken2 物种注释
vi scripts/09_statplot.sh      # 多样性可视化
```

> **提示**：脚本兼容 Markdown 格式，推荐用 VSCode 打开，可在侧边栏看到章节导航。

---

## 目录结构

```
EasyMetagenome/
├── config.sh                  ★ 统一配置文件（唯一需要修改的文件）
├── scripts/                   ★ 模块化分析脚本
│   ├── 02_preprocess.sh       数据预处理（质控 + 去宿主）
│   ├── 03_readbased.sh        基于读长分析（HUMAnN4 / Kraken2）
│   ├── 04_assembly.sh         组装分析（MEGAHIT + 基因预测 + 功能注释）
│   ├── 05_binning.sh          分箱分析（MetaWRAP / dRep / GTDB-tk）
│   ├── 06_isolate_genome.sh   单菌基因组分析（可选）
│   ├── 07_pangenome.sh        泛基因组分析（可选）
│   ├── 08_appendix.sh         常见问题排错手册
│   └── 09_statplot.sh         统计可视化
│
├── 0Install.sh                软件和数据库安装参考（完整版）
├── 1Pipeline.sh               完整流程脚本（原始版，向后兼容）
├── 2StatPlot.sh               可视化脚本（原始版，向后兼容）
├── CHANGELOG.md               版本更新记录
├── environment.yml            Conda 环境配置
│
├── slides/                    培训 PPT（基础知识和分析经验）
├── result/                    分析结果输出目录
│   └── metadata.txt           样本元数据（需用户准备）
├── temp/                      中间文件目录（分析完成后可删除）
└── appendix/                  历史版本和示例
```

---

## 分析模块

### `config.sh` — 统一配置（★ 首先修改此文件）

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `soft` | Conda 安装目录 | `~/miniconda3` |
| `db` | 数据库目录 | `~/db` |
| `wd` | 项目工作目录 | `~/meta` |
| `NPROC` | 线程数 | `8` |
| `NJOB` | 并行样本数 | `2` |
| `GROUP_COL` | metadata 分组列序号 | `3` |
| `READ_LEN` | 测序读长（bp） | `150` |
| `MP4_INDEX` | MetaPhlAn4 数据库索引 | `mpa_vOct22_...` |
| `KRAKEN2_DB` | Kraken2 数据库类型 | `pluspf16g` |
| `BIN_COMP` | 分箱完整度阈值（%） | `50` |
| `BIN_CONT` | 分箱污染率阈值（%） | `10` |

### `scripts/` — 模块说明

| 脚本 | 对应工具 | 主要输出 |
|------|----------|----------|
| `02_preprocess.sh` | Fastp, KneadData | 质控后无宿主序列 |
| `03_readbased.sh` | HUMAnN4, MetaPhlAn4, Kraken2, Bracken | 物种丰度表、功能组成表 |
| `04_assembly.sh` | MEGAHIT, Prodigal, CD-HIT, Salmon, eggNOG, CARD | 基因集、功能注释表 |
| `05_binning.sh` | MetaWRAP, dRep, CoverM, GTDB-tk | MAG 基因组集、物种注释 |
| `06_isolate_genome.sh` | SPAdes, CheckM, MetaWRAP | 单菌高质量基因组 |
| `07_pangenome.sh` | Anvi'o | 泛基因组分析结果 |
| `08_appendix.sh` | — | 常见报错解决方案 |
| `09_statplot.sh` | R 脚本集合 | 多样性图、热图、差异分析图 |

---

## 环境要求

| 资源 | 最低配置 | 推荐配置 |
|------|----------|----------|
| 操作系统 | Linux Ubuntu 20.04 / CentOS 7.7 | Ubuntu 22.04 |
| CPU | 8 核 | 32 核以上 |
| 内存 | 32 GB | 256 GB+ |
| 存储 | 200 GB | 1 TB+ |

**依赖软件**（通过 `0Install.sh` 安装）：

```
conda / mamba  fastp  kneaddata  humann4  metaphlan4  kraken2  bracken
megahit  spades  prodigal  cd-hit  salmon  eggnog-mapper
metawrap  drep  coverm  gtdbtk  checkm2  rgi  lefse  graphlan
```

---

## 数据库需求

| 数据库 | 大小 | 用途 | 下载命令 |
|--------|------|------|----------|
| KneadData 人类基因组 (hg39) | 3.6 GB | 去宿主 | `kneaddata_database --download human_genome bowtie2 ${db}/kneaddata/human` |
| MetaPhlAn4 | ~23 GB | 物种组成 | 见 `0Install.sh` 2.2节 |
| HUMAnN4 ChocoPhlAn | 42 GB | 功能注释 | `humann_databases --download chocophlan full ${db}/humann4` |
| Kraken2 pluspf16g | 16 GB | 物种注释（小内存） | 见 `0Install.sh` 2.3节 |
| Kraken2 pluspf | ~100 GB | 物种注释（人/动物） | 见 `0Install.sh` 2.3节 |
| eggNOG | ~50 GB | 基因功能注释 | `download_eggnog_data.py -y -f --data_dir ${db}/eggnog` |
| GTDB | ~80 GB | MAG 物种注释 | 见 `0Install.sh` 4.4节 |

> 数据库国内备用站点：`ftp://download.nmdc.cn/tools/` （中科院微生物所，FileZilla 访问）
> 百度网盘：<https://pan.baidu.com/s/1Ikd_47HHODOqC3Rcx6eJ6Q?pwd=0315>

---

## 常见问题

**Q: 换了新项目需要修改哪些文件？**
只需修改 `config.sh` 中的 `wd`（工作目录），其余参数保持不变即可。

**Q: `source config.sh` 提示 WARNING 怎么办？**
根据提示检查 `soft` 或 `db` 路径是否存在，路径错误时修改 `config.sh` 中对应变量。

**Q: 脚本是按顺序一次性运行还是逐步执行？**
**交互式逐步执行**。用编辑器打开脚本，理解每节内容后，将命令复制到终端运行。不要直接 `bash scripts/03_readbased.sh` 整体运行。

**Q: 原来用 `1Pipeline.sh` 的方式还能用吗？**
可以，原始文件保留不变，`scripts/` 目录是拆分后的新版本，两者内容一致，按个人习惯选择。

**Q: 更多常见报错请查看：**
`scripts/08_appendix.sh` — 涵盖 KneadData、HUMAnN、Kraken2、MetaWRAP 等常见报错的解决方案。

---

## 引用

使用本流程请引用 / If used, please cite:

> Bai, Defeng, **Tong Chen**, ..., **Yong-Xin Liu**. 2025. "EasyMetagenome: A User-Friendly and Flexible Pipeline for Shotgun Metagenomic Analysis in Microbiome Research." **iMeta** 4: e70001. <https://doi.org/10.1002/imt2.70001>

Copyright 2016–2026 Yong-Xin Liu \<liuyongxin@caas.cn\>, Tong Chen \<chent@nrc.ac.cn\>
