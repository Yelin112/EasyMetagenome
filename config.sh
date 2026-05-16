[TOC]

# EasyMetagenome Configuration (易宏基因组统一配置文件)

    # Authors(作者): Yong-Xin Liu(刘永鑫), Defeng Bai(白德凤), Tong Chen(陈同) et al.
    # Version(版本): 1.24, 2025/11/22
    # Homepage(主页): https://github.com/YongxinLiu/EasyMetagenome
    # Citation(引文): Bai, et al. 2025. EasyMetagenome iMeta 4: e70001. https://doi.org/10.1002/imt2.70001

    # ============================================================
    # MODIFY THIS FILE ONCE — ALL SCRIPTS INHERIT THESE SETTINGS
    # 修改此文件一次——所有脚本继承这些设置
    # ============================================================

    # Conda software installation directory (软件安装目录)
    # e.g. ~/miniconda3 or /anaconda3 — run `conda env list` to confirm
    soft=~/miniconda3

    # Database directory (数据库位置)
    # e.g. ~/db (personal) or /db (administrator)
    db=~/db

    # Work directory for this project (项目工作目录)
    # e.g. ~/meta
    wd=~/meta

    # Number of CPU threads (CPU线程数)
    # Auto-detect: $(nproc); or set manually, e.g. NPROC=8
    NPROC=$(nproc)

    # ============================================================
    # The following lines are applied automatically when sourced.
    # 以下配置在source时自动生效，通常无需修改。
    # ============================================================

    # Add software and scripts to PATH (添加软件和脚本至环境变量)
    PATH=${soft}/bin:${soft}/condabin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${db}/EasyMicrobiome/linux:${db}/EasyMicrobiome/script
    export PATH soft db wd NPROC

    # Platform detection for cross-platform compatibility (平台检测，跨平台兼容)
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: requires coreutils installed via Homebrew (需要通过Homebrew安装coreutils)
        SED="gsed"
        AWK="gawk"
        READLINK="greadlink"
    else
        # Linux
        SED="sed"
        AWK="awk"
        READLINK="readlink"
    fi
    export SED AWK READLINK
