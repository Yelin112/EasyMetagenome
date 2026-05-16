[TOC]

# 02 Data Preprocessing (02数据预处理)

    # Source: extracted from 1Pipeline.sh Section 1
    # Authors(作者): Yong-Xin Liu(刘永鑫), Defeng Bai(白德凤), Tong Chen(陈同) et al.
    # Version(版本): 1.24, 2025/11/22
    # Usage: source config.sh first, then run commands interactively
    # 用法: 先运行 source config.sh，再交互式执行各命令
    source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"
    # ★ MODIFY: edit config.sh to set soft/db/wd/NPROC/NJOB/READ_LEN before running
    # ★ 修改: 在 config.sh 中设置路径和参数，此处无需改动
    mkdir -p $wd && cd $wd
    mkdir -p seq temp result
## 1.1 Preparing(准备工作)

    # 1. First-time use, please refer to the `0Install.sh` to install the software and database (approximately 1-3 days, only once).
    # 2. Copy the EasyMetagenome workflow `1Pipeline.sh` to the project folder, e.g., in this case, `meta`.
    # 3. Prepare the sequencing data (seq/*.fq.gz) and sample metadata (result/metadata.txt) in the project folder.
    # 1.  首次使用请参照`0Install.sh`脚本，安装软件和数据库(大约1-3天，仅一次)
    # 2.  易宏基因组(EasyMetagenome)流程`1Pipeline.sh`复制到项目文件夹，如本次为meta
    # 3.  项目文件夹准备测序数据(seq/*.fq.gz)和样本元数据(result/metadata.txt)

    # **Software, database and work directory settings(数据库、软件和工作目录设置)**
    # **The follwoing paragraph must run before(分析前必须运行)**
    # Conda directory(软件安装目录), e.g. /anaconda3 , `conda env list` view software list,
    soft=~/miniconda3
    # database(db, 数据库位置), e.g. /db or ~/db
    db=~/db
    # work directory(wd, 工作目录)，e.g. meta
    wd=~/meta
    # Create and enter the working directory 创建并进入工作目录
    mkdir -p $wd && cd $wd
    # Create sequences, temporary files, and a results directory 创建序列，临时文件和结果目录
    mkdir -p seq temp result
    # Add software/scripts to environment variables 添加软件/脚本至环境变量
    PATH=$soft/bin:$soft/condabin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$db/EasyMicrobiome/linux:$db/EasyMicrobiome/script
    echo $PATH

    # **Metadata and sequence files (元数据和序列文件) **

    # Metadata (元数据)
    # Edit metadata in Excel then save txt format in result, demo in result or download (编写元数据metadata.txt并保存至result目录，此处下载演示)
    wget -c http://www.imeta.science/github/EasyMetagenome/result/metadata.txt
    mv metadata.txt result/metadata.txt
    # Format check: ^I is tab, $ is linux new line, ^M$ is windows new line, ^M is Mac new line
    # 格式预览，^I为制表符，$为Linux换行，^M$为Windows回车，^M为Mac换行符
    cat -A result/metadata.txt
    # Format windows ^M$ to linux $, delete ^M in regulation expression is '\r'
    # 转换Windows回车为Linux换行，即删除^M (正则表达式为\r)
    sed -i 's/\r//' result/metadata.txt
    cat -A result/metadata.txt

    # Sequencing data (序列文件)
    # Using filezilla upload to seq directory (用户使用filezilla上传测序文件至seq目录)
    # This test uses theChina National Center for Bioinformation's GSA network for downloading data. Backup links are also provided via iMeta and BaiduNetDisk.
    # 本次测试国家生信息中心GSA网络下载，同时提供iMeta、百度网盘备用站点数据下载链接
    
    # Site 1. GSA download links and batch rename by metadata (站点1. 国家生信息中心下载链接，按实验设计编号批量下载并改名)
    # GSA: https://ngdc.cncb.ac.cn/gsa/ search CRA032890, find link test one example C3
    wget -c ftp://download.big.ac.cn/gsa5/CRA032890/1/CRR2274865/CRR2274865_r1.fq.gz -O seq/C3_1.fq.gz
    wget -c ftp://download.big.ac.cn/gsa5/CRA032890/1/CRR2274865/CRR2274865_r2.fq.gz -O seq/C3_2.fq.gz
    awk 'BEGIN{OFS=FS="\t"}{system("wget -c ftp://download.big.ac.cn/gsa5/"$8"/"$9"/"$9"_r1.fq.gz -O seq/"$1"_1.fq.gz")}' \
        <(tail -n+2 result/metadata.txt)
    awk 'BEGIN{OFS=FS="\t"}{system("wget -c ftp://download.big.ac.cn/gsa5/"$8"/"$9"/"$9"_r2.fq.gz -O seq/"$1"_2.fq.gz")}' \
        <(tail -n+2 result/metadata.txt)

    # Site 2. iMeta Science download link （站点2. iMeta下载链接）
    cd seq
    awk '{system("wget -c http://www.imeta.science/github/EasyMetagenome/seq/"$1"_1.fq.gz")}' <(tail -n+2 ../result/metadata.txt)
    awk '{system("wget -c http://www.imeta.science/github/EasyMetagenome/seq/"$1"_2.fq.gz")}' <(tail -n+2 ../result/metadata.txt)
    cd ..

    # Site 3. BaiduNetDisk (站点3. 百度网盘) in /db/meta/seq directory from https://pan.baidu.com/s/1Ikd_47HHODOqC3Rcx6eJ6Q?pwd=0315

    # ls show file info, -l (l: list) show detail, -sh s: size, h: human readable
    # ls查看文件大小等信息，-l 列出详细信息 (l: list)，-sh 显示人类可读方式文件大小 (s: size; h: human readable)
    ls -lsh seq/*.fq.gz
    # Statistic basic info of sequences 统计序列信息
    time seqkit stat seq/*.fq.gz > result/seqkit.txt
    cat result/seqkit.txt

    # **Sequence file format check (序列文件格式检查)**
    # Use zless/zcat to view compressible files and check the sequence quality format 
    # (quality values in uppercase are in standard Phred33 format, lowercase in Phred64 format);
    # check if the pair-end sequence IDs have duplicate names, and if so, rename them. 
    # Refer to **Appendix – Quality Control kneaddata: End-to-End Mismatch After Host Removal; Sequence Renaming**.
    # zless/zcat查看可压缩文件，检查序列质量格式(质量值大写字母为标准Phred33格式，小写字母为Phred64)；
    # 检查双端序列ID是否重名，如重名需要改名。参考**附录 —— 质控kneaddata，去宿主后双端不匹配；序列改名**。

    # Set a sample name be variable i, which can be reused multiple times, reducing the number of modifications required.
    # 设置某个样本名为变量i，后面可多次重用，减少修改次数
    i=C1
    # zless is used to view compressed files; spacebar to turn pages, q to exit; head specifies the number of lines to display.
    # zless查看压缩文件，空格翻页，q退出; head指定显示行数
    zless seq/${i}_1.fq.gz | head -n4

    # **Summary of Working Directory and File Structure**
    # **工作目录和文件结构总结**
    # ├── pipeline.sh
    # ├── result
    # │   └── metadata.txt
    # ├── seq
    # │   ├── C1_1.fq.gz
    # │   ├── ...
    # │   └── Y1_2.fq.gz
    # └── temp

    # * `1pipeline.sh` is the analysis workflow code;
    # * The `seq` directory contains 6 samples of short-reads paired-end 150 bp sequencing and 12 sequence files;
    # * `temp` is a temporary folder that stores intermediate analysis files. It can be deleted entirely after analysis to save space;
    # * `result` contains important node files and formatted analysis results figures. `metadata.txt` is also located here.
    # *   1pipeline.sh是分析流程代码；
    # *   seq目录中有2个样本Illumina双端测序，4个序列文件；
    # *   temp是临时文件夹，存储分析中间文件，结束可全部删除节约空间
    # *   result是重要节点文件和整理化的分析结果图表，实验设计metadata.txt也在此

## 1.2 Fastp Quality Control(质量控制)

    # Create a directory to record software versions and citations
    # 创建目录，记录软件版本和引文
    mkdir -p temp/qc result/qc
    fastp
    
    # Single sample quality control (单样本质控)
    i=`tail -n+2 result/metadata.txt|cut -f1|head -n1`
    fastp -i seq/${i}_1.fq.gz  -I seq/${i}_2.fq.gz \
      -o temp/qc/${i}_1.fastq -O temp/qc/${i}_2.fastq
    
    # Multiple samples are processed in parallel; this step requires 5 times the space of the original data.
    # 多样本并行，此步占用原始数据5x空间
    # -j 2: indicates processing 2 samples simultaneously; for 6 samples, j2, 2minmutes 
    # -j 2: 表示同时处理2个样本；6个样本j2, 2分钟(minutes, m)
    time tail -n+2 result/metadata.txt|cut -f1|rush -j ${NJOB} \
      "fastp -i seq/{1}_1.fq.gz -I seq/{1}_2.fq.gz \
        -j temp/qc/{1}_fastp.json -h temp/qc/{1}_fastp.html \
        -o temp/qc/{1}_1.fastq  -O temp/qc/{1}_2.fastq \
        > temp/qc/{1}.log 2>&1"
    
    # Summary of Quality Control Results (质控后结果汇总)
    echo -e "SampleID\tRaw\tClean" > temp/fastp
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do
        echo -e -n "$i\t" >> temp/fastp
        grep 'total reads' temp/qc/${i}.log|uniq|cut -f2 -d ':'|tr '\n' '\t' >> temp/fastp
        echo "" >> temp/fastp
        done
    sed -i 's/ //g;s/\t$//' temp/fastp
    # Sort by metadata (按metadata排序)
    awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$1]=$0}NR>FNR{print a[$1]}' temp/fastp result/metadata.txt \
      > result/qc/fastp.txt
    cat result/qc/fastp.txt
    
## 1.3 KneadData Host removal (去宿主)

    # The kneaddata relies on bowtie2 to align with the host sequence, and then filters out non-host sequences for downstream analysis.
    # kneaddata是流程主要依赖bowtie2比对宿主，然后筛选非宿主序列用于下游分析。

    # Create directories, activate the environment, and record versions.
    # 创建目录、启动环境、记录版本
    mkdir -p temp/hr
    conda activate kneaddata
    kneaddata --version # v0.12.3

    # Single-sample host removal (单样本去宿主)
    i=`tail -n+2 result/metadata.txt|cut -f1 | head -n1`
    time kneaddata -i1 temp/qc/${i}_1.fastq -i2 temp/qc/${i}_2.fastq \
        -o temp/hr \
        --bypass-trim --bypass-trf --reorder \
        --bowtie2-options '--very-sensitive --dovetail' \
        -db ${db}/kneaddata/human/hg_39 \
        --remove-intermediate-output -v -t ${NPROC}

    # Multi-sample host removal, this step occupies 5 times the space of the original data, 3m
    # 多样本去宿主,此步占用原始数据5x空间,5m
    time tail -n+3 result/metadata.txt | cut -f1 | rush -j ${NJOB} \
      "kneaddata \
        -i1 temp/qc/{1}_1.fastq -i2 temp/qc/{1}_2.fastq \
        -o temp/hr/ \
        --bypass-trim --bypass-trf --reorder \
        --bowtie2-options '--very-sensitive --dovetail' \
        -db ${db}/kneaddata/human/hg_39 \
        --remove-intermediate-output -v -t ${NPROC}"

    # To check the size, * matches any number of characters, and ? matches any single character.
    # 查看大小，*匹配任意多个字符，?匹配任意一个字符
    ls -shtr temp/hr/*_paired_?.fastq

    # Simplified renaming (简化改名)
    # Ubuntu System renaming (Ubuntu系统改名)
    rename 's/_1_kneaddata_paired//' temp/hr/*.fastq
    # CentOS System renaming (CentOS系统改名)
    rename '_1_kneaddata_paired' '' temp/hr/*.fastq

    # Summary of Quality Control Results (质控结果汇总)
    kneaddata_read_count_table --input temp/hr \
      --output temp/kneaddata.txt
    # Filter key results column (筛选重点结果列)
    cut -f 1,2,5,6 temp/kneaddata.txt | sed 's/_1_kneaddata//' > result/qc/sum.txt
    # View table alignment (对齐方式查看表格)
    csvtk -t pretty result/qc/sum.txt

    # Verify if the IDs match in pair-end reads (校验ID是否配对)
    paste <(head -n40 temp/hr/`tail -n+2 result/metadata.txt|cut -f1|head -n1`_1.fastq|grep @)    <(head -n40 temp/hr/`tail -n+2 result/metadata.txt|cut -f1|head -n1`_2.fastq|grep @)

    # Large file cleanup: samples with high host content can save >90% of space.
    # 大文件清理，高宿主含量样本可节约>90%空间
    # Using the absolute path of a command ensures that it is a parameterless command. Administrators can use aliases to define commands with parameters, which can affect the operation results.
    # 使用命令的绝对路径确保使用无参数的命令，管理员用alias自定义命令含参数，影响操作结果
    /bin/rm -rf temp/hr/*contam* temp/hr/*unmatched* temp/hr/reformatted* temp/hr/_temp*
    ls -l temp/hr/
    # After confirming the host removal results, the intermediate files after quality control can be deleted
    # 确认去宿主结果后，可以删除质控后中间文件
    rm temp/qc/*.fastq
    # Human data should be published as dehosted files to reduce the risk of privacy leaks.
    # 人类数据建议发布去宿主后的文件，减少隐私泄露风险
    
