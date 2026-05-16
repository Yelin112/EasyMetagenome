[TOC]

# EasyMetagenome Configuration (易宏基因组统一配置文件)

    # Authors(作者): Yong-Xin Liu(刘永鑫), Defeng Bai(白德凤), Tong Chen(陈同) et al.
    # Version(版本): 1.24, 2025/11/22
    # Homepage(主页): https://github.com/YongxinLiu/EasyMetagenome
    # Citation(引文): Bai, et al. 2025. EasyMetagenome iMeta 4: e70001. https://doi.org/10.1002/imt2.70001
    # Platform(平台): Linux Ubuntu 22.04+ / CentOS 7.7+

    # ============================================================
    # ★ SECTION 1: USER SETTINGS — MODIFY BEFORE FIRST USE
    # ★ 第一节：用户设置——首次使用前必须修改
    # ============================================================

    # Conda software installation directory (软件安装目录)
    # Run `conda env list` to confirm the path (运行确认路径)
    soft=~/miniconda3

    # Database directory (数据库位置)
    # Personal: ~/db; Administrator: /db
    db=~/db

    # Work directory for THIS project (本项目的工作目录)
    # Each project should use its own directory (每个项目独立目录)
    wd=~/meta

    # ============================================================
    # ★ SECTION 2: ANALYSIS PARAMETERS — TUNE PER PROJECT
    # ★ 第二节：分析参数——每个项目按需调整
    # ============================================================

    # CPU threads per task (每个任务的CPU线程数)
    # Recommended: 8–32 depending on server (建议8–32，视服务器配置)
    NPROC=8

    # Number of parallel jobs (并行任务数)
    # NPROC × NJOB ≤ total CPU cores (线程数×任务数≤总核数)
    NJOB=2

    # Metadata group column index (元数据分组列序号，从1开始)
    # Column in result/metadata.txt containing group labels (result/metadata.txt中分组所在列)
    GROUP_COL=3

    # Sequencing read length in bp (测序读长，单位bp)
    # Used by Bracken abundance estimation (用于Bracken丰度估算)
    READ_LEN=150

    # MetaPhlAn4 database index name (MetaPhlAn4数据库索引名)
    # Check available indices: ls ${db}/metaphlan4/ (查看可用索引)
    MP4_INDEX=mpa_vOct22_CHOCOPhlAnSGB_202403

    # Kraken2 database type (Kraken2数据库类型)
    # pluspf16g: 16GB, suitable for small memory servers (小内存服务器)
    # pluspf: ~100GB, human/animal samples (人/动物样本)
    # pluspfp: ~214GB, plant/soil samples (植物/土壤样本)
    KRAKEN2_DB=pluspf16g

    # Binning quality thresholds (分箱质量阈值)
    # BIN_COMP: minimum completeness %, BIN_CONT: maximum contamination %
    BIN_COMP=50
    BIN_CONT=10

    # Bracken filtering: minimum sample presence proportion (Bracken过滤：最低样本占比)
    # 0.2 = keep taxa present in at least 20% of samples (保留至少20%样本中存在的分类单元)
    BRACKEN_PROP=0.2

    # ============================================================
    # SECTION 3: AUTO-APPLIED — DO NOT MODIFY BELOW THIS LINE
    # 第三节：自动配置——以下内容无需修改
    # ============================================================

    # Add software and scripts to PATH (添加软件和脚本至环境变量)
    PATH=${soft}/bin:${soft}/condabin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${db}/EasyMicrobiome/linux:${db}/EasyMicrobiome/script
    export PATH soft db wd NPROC NJOB GROUP_COL READ_LEN MP4_INDEX KRAKEN2_DB BIN_COMP BIN_CONT BRACKEN_PROP

    # Environment check (环境检查)
    _check_env() {
        local ok=1
        [[ -d "${soft}" ]] || { echo "[config] WARNING: soft directory not found: ${soft}"; ok=0; }
        [[ -d "${db}" ]]   || { echo "[config] WARNING: db directory not found: ${db}"; ok=0; }
        command -v conda &>/dev/null || { echo "[config] WARNING: conda not found in PATH"; ok=0; }
        [[ $ok -eq 1 ]] && echo "[config] Environment OK: soft=${soft} db=${db} wd=${wd} NPROC=${NPROC} NJOB=${NJOB}"
    }
    _check_env
