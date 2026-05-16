[TOC]

# 05 Binning: Mining Single-Bacterial Genomes (05分箱挖掘单菌基因组)

    # Source: extracted from 1Pipeline.sh Section 4
    # Authors(作者): Yong-Xin Liu(刘永鑫), Defeng Bai(白德凤), Tong Chen(陈同) et al.
    # Version(版本): 1.24, 2025/11/22
    # Usage: source config.sh first, then run commands interactively
    # 用法: 先运行 source config.sh，再交互式执行各命令
    source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"
    cd $wd
## MetwWRAP binning (分箱)

    # GitHub: https://github.com/bxlab/metaWRAP
    # For mining single-bacterial genomes, a single sample size of 6GB+ is recommended, and for complex samples such as soil, a data size of 30GB+ is recommended. 
    # The demonstration data consists of 6 samples (approximately 1GB), which is insufficient to obtain single-bacterial genomes. Therefore, official sequencing data is used for demonstration and explanation.
    # 挖掘单菌基因组，推荐单样本6GB+，复杂样本如土壤推荐数据量30GB+
    # 演示数据6个样品~1G，无法获得单菌基因组，这里使用官方测序数据演示讲解

    cd $wd
    conda activate metawrap
    metawrap -v # 1.3.2
    mkdir -p temp/bin temp/bin_refine temp/drep_in result/bin

    # Input: quaility control & host removal sequences, *_1.fastq和*_2.fastq,  
    #        assemble contigs, temp/megahit/final.contigs.fa
    # Output: Binning result: temp/bin
    #     Stat：temp/bin_refine/metawrap_50_10_bins.stats

### All samples mix Binning (多样本混合分箱)

    # Using maxbin2, metabat2，3p41m；32p 18sample 16-19h
    metawrap binning -o temp/bin \
      -t 3 -a temp/megahit/final.contigs.fa \
      --metabat2 --maxbin2 \
      temp/hr/*.fastq
    #  --concoct > /dev/null 2>&1 # increase 3~10 fold calculating, /dev/null omit Warning

    ### Bin refinement (分箱提纯), 8p1h
    metawrap bin_refinement \
      -o temp/bin_refine \
      -A temp/bin/metabat2_bins/ \
      -B temp/bin/maxbin2_bins/ \
      -c 50 -x 10 -t 8
    # -C temp/bin/concoct_bins/ \
    # Bin count 22
    tail -n+2 temp/bin_refine/metawrap_50_10_bins.stats|wc -l
    # Plot in temp/bin_refine/figures/

    # Together: all bins in one directory (所有分箱至同一目录)
    # Mix binning link and rename (混合组装分箱链接和重命名)
    ln -s `pwd`/temp/bin_refine/metawrap_50_10_bins/bin.* temp/drep_in/
    ls -l temp/drep_in/
    # CentOS rename
    rename 'bin.' 'Mx_All_' temp/drep_in/bin.*
    # Ubuntu rename
    rename s/bin./Mx_All_/ temp/drep_in/bin.*
    ls temp/drep_in/Mx*

### Single sample binning (单样本分箱)

    # When multiple samples cannot be completed due to hardware or computation time limitations, 
    # single-sample assembly and binning are required. Multiple samples offer greater information abundance, 
    # resulting in more binned products and making it easier to reduce contamination.
    # 多样本受硬件、计算时间限制无法完成时，需要单样本组装、分箱。多样本信息丰度，分箱结果更多，更容易降低污染。

    # Configure global threads, number of parallel tasks, and conditions for filtering bins.
    # 设置全局线程、并行任务数和筛选分箱的条件
    # p: threads (线程数), j: job (任务数), c: complete (完整度), x: contaminate (污染率)
    p=16
    j=3
    c=50
    x=10
    
    # Assemble(组装), 10min; 18s6h
    time tail -n+2 result/metadata.txt|cut -f1|rush -j ${j} \
      "metawrap assembly -m 200 -t ${p} --megahit \
        -1 temp/hr/{}_1.fastq -2 temp/hr/{}_2.fastq \
        -o temp/megahit/{}"

    # Binning (分箱), 3m
    time tail -n+2 result/metadata.txt|cut -f1|rush -j ${j} \
      "metawrap binning \
        -o temp/bin/{} -t ${p} \
        -a temp/megahit/{}/final_assembly.fasta \
        --metabat2 --maxbin2 \
        temp/hr/{}_*.fastq" # --concoct > /dev/null 2>&1

    # Bin refinement (分箱提纯), 42m
    time tail -n+2 result/metadata.txt|cut -f1|rush -j ${j} \
      "metawrap bin_refinement \
      -o temp/bin_refine/{} -t ${p} \
      -A temp/bin/{}/metabat2_bins/ \
      -B temp/bin/{}/maxbin2_bins/ \
      -c ${c} -x ${x}"
      # -C temp/bin/{}/concoct_bins/ \
    # 分别为1,2,2个
    tail -n+2 result/metadata.txt|cut -f1|rush -j 1 \
      "tail -n+2 temp/bin_refine/{}/metawrap_50_10_bins.stats|wc -l "

    # Together, link and rename (单样品分箱链接和重命名)
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do
       ln -s `pwd`/temp/bin_refine/${i}/metawrap_50_10_bins/bin.* temp/drep_in/
       rename 'bin.' "Sg_${i}_" temp/drep_in/bin.*
       rename "s/bin./Sg_${i}_/" temp/drep_in/bin.*
    done
    # Delete fail link (删除空白中无效链接)
    # /bin/rm -f temp/drep_in/*\*
    # Bin source, 22 mix, 22 single sample
    ls temp/drep_in/|cut -f 1 -d '_'|uniq -c
    # Bin source, each sample
    ls temp/drep_in/|cut -f 2 -d '_'|cut -f 1 -d '.' |uniq -c


### (Opt) Subgroup binning (可选)分组分箱

    # For samples >30 or data volume >300G, completing hybrid assembly and binning on a 1TB memory fat node may result in insufficient memory and take >1 week or even 1 month. It is necessary to divide the research into small groups based on similar conditions and locations, and each group should write a metadata.txt file.
    # 样本>30或数据量>300G在1TB内存胖结点上完成混合组装和分箱可能内存不足、且时间>1周甚至1月，需要对研究相近条件、地点进行分小组，且每组编写一个metadata??.txt。

    # Group: Young/Centenarians
    g=Young
    grep -P "Group|${g}" result/metadata.txt > result/meta${g}.txt
    cat result/meta${g}.txt

    # Assemble, 9m, <30 samples or <300G data, ~12h
    metawrap assembly -m 600 -t 32 --megahit \
      -1 `tail -n+2 result/meta${g}.txt|cut -f1|sed 's/^/temp\/hr\//;s/$/_1.fastq/'|tr '\n' ','|sed 's/,$//'` \
      -2 `tail -n+2 result/meta${g}.txt|cut -f1|sed 's/^/temp\/hr\//;s/$/_2.fastq/'|tr '\n' ','|sed 's/,$//'` \
      -o temp/megahit_${g}

    # Prepare data directory
    mkdir -p temp/${g}/
    for i in `tail -n+2 result/meta${g}.txt|cut -f1`;do
        ln -s `pwd`/temp/hr/${i}*.fastq temp/${g}/; done
    # Bin (分箱), 4m
    metawrap binning -o temp/bin/${g} \
      -t 32 -a temp/megahit_${g}/final_assembly.fasta \
      --metabat2 --maxbin2 \
      temp/${g}/*.fastq

    # Bin refinement (分箱提纯), 30m
    metawrap bin_refinement \
      -o temp/bin_refine/${g} \
      -A temp/bin/${g}/metabat2_bins/ \
      -B temp/bin/${g}/maxbin2_bins/ \
      -c 50 -x 10 -t 32
    wc -l temp/bin_refine/${g}/metawrap_50_10_bins.stats

    # Together, link and rename (单样品分箱链接和重命名)
    ln -s `pwd`/temp/bin_refine/${g}/metawrap_50_10_bins/bin.* temp/drep_in/
    rename "s/bin./Gp_${g}_/" temp/drep_in/bin.* # Ubuntu
    rename 'bin.' "Gp_${g}_" temp/drep_in/bin.* # CentOS

    # Stat each type and sample
    echo -e "Type\tCount" > result/bin/count.txt
    ls temp/drep_in/|cut -f 1 -d '_'|uniq -c|awk '{print $2"\t"$1}' >> result/bin/count.txt
    ls temp/drep_in/|cut -f 1-2 -d '_'|uniq -c|awk '{print $2"\t"$1}' >> result/bin/count.txt
    cat result/bin/count.txt

### Option. CheckM2 Reassessment (可选. 重新评估)

    conda activate checkm2
    mkdir -p temp/checkm2 result/checkm2
    # 22 genomes, 2m
    time checkm2 predict --input temp/drep95/dereplicated_genomes/* \
      --output-directory temp/checkm2 --threads 8
    ln temp/checkm2/quality_report.tsv result/checkm2/
    less result/checkm2/quality_report.tsv 

## 4.2 dRep genome redundance (基因组去冗余)

    cd $wd
    conda activate drep
    mkdir -p temp/drep95

    # dereplicate by species：10 min; 44 genome, 22 from mix samples, 22 from signle samle
    time dRep dereplicate temp/drep95/ \
      -g temp/drep_in/*.fa  \
      -sa 0.95 -nc 0.30 -comp 50 -con 10 -p 8
    # log in temp/drep95/log/cmd_logs, -d show more detail
    ls temp/drep95/dereplicated_genomes/|cut -f 1 -d '_'|sort|uniq -c
    # ls temp/drep95/dereplicated_genomes/|sed 's/.fa//' > temp/drep95/data_tables/id
    # format_drep2cluster.pl -i temp/drep95/data_tables/Cdb.csv -d temp/drep95/data_tables/id \
    #   -o temp/drep95/data_tables/Cdb.list -h header num

    # main result in temp/drep95
    # 1. Redundancy genome catalogue (非冗余基因组集)：temp/drep95/dereplicated_genomes/*.fa
    # 2. Table(聚类表): temp/drep95/data_tables/Cdb.csv
    # 3. Plot(聚类和质量图)：temp/drep95/figures/*clustering*

    # (Option) drep in 99% strain level, 7m (可选)按株水平99%去冗余，20-30min
    mkdir -p temp/drep99
    time dRep dereplicate temp/drep99/ \
      -g temp/drep_in/*.fa \
      -sa 0.99 -nc 0.30 -comp 50 -con 10 -p 16
    # species level 26, strain level 29
    ls -l temp/drep99/dereplicated_genomes/ | grep '.fa' | wc -l

## 4.3 CoverM quantify in genome (基因组定量)

    conda activate coverm
    mkdir -p temp/coverm
    
    # Single test, Y1 30s
    i=`tail -n+2 result/metadata.txt|cut -f1 | head -n1`
    time coverm genome --coupled temp/hr/${i}_1.fastq temp/hr/${i}_2.fastq \
      --genome-fasta-directory temp/drep95/dereplicated_genomes/ -x fa \
      -o temp/coverm/${i}.txt
    cat temp/coverm/${i}.txt
    
    # Parallel, 4min；注：尝试拆分2步，节省建索引时间
    tail -n+3 result/metadata.txt|cut -f1|rush -j 2 \
      "coverm genome --coupled temp/hr/{}_1.fastq temp/hr/{}_2.fastq -t 3 \
      --genome-fasta-directory temp/drep95/dereplicated_genomes/ -x fa \
      -o temp/coverm/{}.txt > temp/coverm/{}.log "

    # Merge to table (结果合并)
    mkdir -p result/coverm
    conda activate humann4
    sed -i 's/_1.fastq Relative Abundance (%)//' temp/coverm/*.txt
    humann_join_tables --input temp/coverm --file_name txt --output result/coverm/abundance.tsv
    csvtk -t stat result/coverm/abundance.tsv

    # Group mean (按组求均值，需要metadata中有3列且每个组有多个样本)
    Rscript ${db}/EasyMicrobiome/script/otu_mean.R --input result/coverm/abundance.tsv \
      --metadata result/metadata.txt \
      --group Group --thre 0 \
      --scale TRUE --zoom 100 --all TRUE --type mean \
      --output result/coverm/group_mean.txt
    # https://www.bic.ac.cn/ImageGP/ 直接选择热图可视化

## 4.4 GTDB taxonomic classifications of prokaryote (原核基因组注释和进化树)

    conda activate gtdbtk
    export GTDBTK_DATA_PATH="${db}/gtdb"
    gtdbtk -v # 2.5.2
    
    # Classify, 8p, 22 genomes, 40m
    mkdir -p temp/gtdb_classify
    time gtdbtk classify_wf \
        --genome_dir temp/drep95/dereplicated_genomes \
        --out_dir temp/gtdb_classify \
        --extension fa --skip_ani_screen \
        --prefix tax \
        --cpus 8
    # less -S view, press q quit; 26 bac short for Bacterial, 0 ar short for Archaea
    less -S temp/gtdb_classify/tax.bac120.summary.tsv
    less -S temp/gtdb_classify/tax.ar53.summary.tsv

    # (Optional) Annotations for all MAG species (可选)所有MAG物种注释
    mkdir -p temp/gtdb_all
    # 10000 genome，32p，100min
    time gtdbtk classify_wf --genome_dir temp/drep_in/ \
        --out_dir temp/gtdb_all --extension fa --skip_ani_screen \
        --prefix tax --cpus 32
    
    # multi-sequence alignment and phylogenetic tree (多序列对齐结果建树)
    mkdir -p temp/gtdb_infer
    gtdbtk infer --msa_file temp/gtdb_classify/align/tax.bac120.user_msa.fasta.gz \
        --out_dir temp/gtdb_infer --prefix tax --cpus 3
    # tree `tax.unrooted.tree` using iTOL online visualization

    # Tree annotation: gtdb-tk taxonomy (tax.bac120.summary.tsv) and drep genome info(Widb.csv)
    mkdir -p result/itol
    # Taxonomy table (分类学表)
    tail -n+2 temp/gtdb_classify/tax.bac120.summary.tsv|cut -f 1-2|sed 's/;/\t/g'|sed '1 s/^/ID\tDomain\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\n/' > result/itol/tax.txt
    head result/itol/tax.txt
    # Genome info (基因组评估信息)
    sed 's/,/\t/g;s/.fa//' temp/drep95/data_tables/Widb.csv|cut -f 1-7,11|sed '1 s/genome/ID/' > result/itol/genome.txt
    head result/itol/genome.txt
    # Merge (整合注释文件)
    awk 'BEGIN{OFS=FS="\t"} NR==FNR{a[$1]=$0} NR>FNR{print $0,a[$1]}' result/itol/genome.txt result/itol/tax.txt|cut -f 1-8,10- > result/itol/annotation.txt
    head result/itol/annotation.txt
    # Add relative abundance of each sample/group (添加各样本/组相对丰度)
    awk 'BEGIN{OFS=FS="\t"} NR==FNR{a[$1]=$0} NR>FNR{print $0,a[$1]}' <(sed '1 s/Genome/ID/' result/coverm/abundance.tsv) result/itol/annotation.txt|cut -f 1-15,17- > result/itol/annotation2.txt
    head result/itol/annotation2.txt    

