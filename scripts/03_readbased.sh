[TOC]

# 03 Read-based Analysis: HUMAnN4 / MetaPhlAn4 / Kraken2 (03基于读长分析)

    # Source: extracted from 1Pipeline.sh Section 2
    # Authors(作者): Yong-Xin Liu(刘永鑫), Defeng Bai(白德凤), Tong Chen(陈同) et al.
    # Version(版本): 1.24, 2025/11/22
    # Usage: source config.sh first, then run commands interactively
    # 用法: 先运行 source config.sh，再交互式执行各命令
    source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"
    cd $wd
## 2.1 HUMAnN4分析

    # HUMAnN 4: https://docs.google.com/document/d/1rCx5JkuO7wCKWrL8_-UJx_FkopJAfcDFtZktgPspak0/edit?pli=1&tab=t.0

### HUMAnN4 taxonomic and functional annotation (物种和功能分析)

    # Prepare input file (准备输入文件)
    # HUMAnN requires a file containing paired-end sequences to be merged as input. 
    # A for loop is used to merge paired-end sequences in batches according to the experimental design sample names. 
    # Note the asterisk (*) and question mark (?), which represent multiple and a single character, respectively. 
    # Of course, you must also pay attention to the fact that each line of code ends with a backslash (\\).
    # HUMAnN要求双端序列合并的文件作为输入，for循环根据实验设计样本名批量双端序列合并。
    # 注意星号(\*)和问号(?)，分别代表多个和单个字符。当然大家更不能溜号，行分割的代码行末有一个\\

    mkdir -p temp/concat
    # Merge pair-end files into a single file (双端合并为单个文件)
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do 
      cat temp/hr/${i}_?.fastq \
      > temp/concat/${i}.fq; done &
    # Check sample quantity and size (查看样品数量和大小)
    ls -shl temp/concat/*.fq
    # The data is too large and the computation time is long. You can use head to truncate the single-end analysis to a 20M sequence, i.e., 3G, with 80M lines. See Appendix: HUANN2 Reduce Input File Speedup.
    # 数据太大，计算时间长，可用head对单端分析截取20M序列，即3G，行数为80M行，详见附录：HUMAnN2减少输入文件加速

    # HUMAnN4 analysis tutorial and test (教学和测试)
    # *   Taxonomic annotation call MetaPhlAn4 (物种组成调用)
    # *   Input(输入)：temp/concat/*.fq Merged sequences (合并的序列)
    # *   Output(输出)：temp/humann4/
    #     *   Y1_pathabundance.tsv
    #     *   Y1_pathcoverage.tsv
    #     *   Y1_genefamilies.tsv
    
    # Start the humann4 environment and check the database configuration (启动环境并检查数据库配置)
    conda activate humann4
    mkdir -p temp/humann4
    humann --version # v4.0.0.alpha.1
    humann_config

    # Single-sample test (单样本测试): Y1 657M, 8p, 32min
    i=`tail -n+2 result/metadata.txt|cut -f1 | head -n1`
    time humann --input temp/concat/${i}.fq --threads 8 \
      --metaphlan-options "--input_type fastq --bowtie2db ${db}/metaphlan4 --index mpa_vOct22_CHOCOPhlAnSGB_202403 --offline -t rel_ab_w_read_stats --nproc 8" \
      --output temp/humann4
      
    # Multi-sample parallel computing, test data with 6 samples in dual parallel: 2h, recommended 16p, 3h/6G;
    # 多样本并行计算，测试数据6个样本双并行：2h，推荐16p，3h/6G；
    # -n+3 start from second samples, --threads set 8/16/32 to accelerate
    time tail -n+3 result/metadata.txt | cut -f1 | rush -j 2 \
      "humann --input temp/concat/{1}.fq --threads 8 \
        --metaphlan-options '--input_type fastq --bowtie2db ${db}/metaphlan4 --index mpa_vOct22_CHOCOPhlAnSGB_202403 --offline -t rel_ab_w_read_stats --nproc 8'  \
        --output temp/humann4/ "

    # (Optional) Run MetaPhlAn4 separately (可选)单独运行MetaPhlAn4
    metaphlan -v # MetaPhlAn version 4.1.1 (11 Mar 2024)
    mkdir -p temp/metaphlan4
    i=`tail -n+2 result/metadata.txt|cut -f1 | head -n1`
    # taxonomy classification 8p, 4min
    time metaphlan --input_type fastq temp/hr/${i}_1.fastq \
      temp/metaphlan4/${i}.txt --nproc 8 --bowtie2db ${db}/metaphlan4 --index mpa_vOct22_CHOCOPhlAnSGB_202403 --offline

### Taxonomic composition table (物种组成表)

    # Output(输出)：
    #   result/metaphlan4/taxonomy.tsv
    #   result/metaphlan4/taxonomy.spf spf for STAMP（用于STAMP分析）
    
    # Sample Merge, correct name, preview (样品合并、修正ID、预览) | sed '2i #metaphlan4'
    mkdir -p result/metaphlan4
    merge_metaphlan_tables.py temp/humann4/*_metaphlan_profile.tsv | sed 's/_1_metaphlan//g' | tail -n+2 | sed '1 s/clade_name/ID/' | sed '2i #metaphlan4' \
      > result/metaphlan4/taxonomy.tsv
    csvtk -t stat result/metaphlan4/taxonomy.tsv
    head -n5 result/metaphlan4/taxonomy.tsv

    # Format to stamp spf(转换为STAMP输入spf格式)
    # duplicate rows redandency by sort & uniq 
    metaphlan_to_stamp.pl result/metaphlan4/taxonomy.tsv \
      |sort -r | uniq > result/metaphlan4/taxonomy.spf
    # stat and view, 14 columns, 274 rows
    csvtk -t stat result/metaphlan4/taxonomy.spf
    head result/metaphlan4/taxonomy.spf
    # STAMP not support unclassified, filtered left 203 row
    grep -v 'unclassified' result/metaphlan4/taxonomy.spf > result/metaphlan4/taxonomy2.spf
    csvtk -t stat result/metaphlan4/taxonomy2.spf
    head result/metaphlan4/taxonomy2.spf
    # Download metadata.txt & taxonomy2.spf, and open in STAMP software 结果文件下载可用STAMP分析

## 2.4 Functional composition analysis (功能组成分析)

    # 整合后的输出：
    # *   result/metaphlan4/taxonomy.tsv 物种丰度表
    # *   result/metaphlan4/taxonomy.spf 物种丰度表（用于stamp分析）
    # *   result/humann3/pathabundance_relab_unstratified.tsv 通路丰度表
    # *   result/humann3/pathabundance_relab_stratified.tsv 通路物种组成丰度表
    # *   stratified(每个菌对此功能通路组成的贡献)和unstratified(功能组成)

    # Samples merging table (样本合并为功能组成表)
    mkdir -p result/humann4
    humann_join_tables --input temp/humann4 \
      --file_name pathabundance \
      --output result/humann4/path.tsv
    # format sampleID, stat and view, 样本名统一、统计和预览
    sed -i 's/_Abundance//g' result/humann4/path.tsv
    csvtk -t stat result/humann4/path.tsv
    head -n5 result/humann4/path.tsv

    # Normolization to relative abundance relab(1) or per million cpm(1,000,000) (标准化为相对丰度relab或百万比cpm)
    humann_renorm_table \
      --input result/humann4/path.tsv \
      --units relab \
      --output result/humann4/path_relab.tsv
    head -n5 result/humann4/path_relab.tsv

    # Stratify into function related species (stratified) and function only (unstratified) 分层为功能包括物种组成和仅功能组成
    humann_split_stratified_table \
      --input result/humann4/path_relab.tsv \
      --output result/humann4/ 

### Difference comparison and bar chart (差异比较和柱状图)

    # * Input: Pathway abundance table result/humann4/path.tsv and experimental design result/metadata.txt
    # * Intermediate: Pathway abundance table file containing grouping information result/humann4/path.pcl
    # * Output: result/humann4/associate.txt
    # *   输入数据：通路丰度表格 result/humann4/path.tsv和实验设计 result/metadata.txt
    # *   中间数据：包含分组信息的通路丰度表格文件 result/humann4/path.pcl
    # *   输出结果：result/humann4/associate.txt

    # Add grouping to pathway abundance (在通路丰度中添加分组)
    # List of samples ID (提取样品列表)
    head -n1 result/humann4/path.tsv | sed 's/# Pathway HUMAnN v4.0.0.alpha.1/SampleID/' | tr '\t' '\n' > temp/header
    # The sample corresponds to group; in this example group is the 3rd column ($3) 样本对应分组，本示例分组为第3列($3)
    awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$1]=$3}NR>FNR{print a[$1]}' result/metadata.txt temp/header | tr '\n' '\t'|sed 's/\t$/\n/' > temp/group
    # replace grouping
    cat <(head -n1 result/humann4/path.tsv) temp/group <(tail -n+2 result/humann4/path.tsv) \
      > result/humann4/path.pcl
    head -n5 result/humann4/path.pcl
    tail -n5 result/humann4/path.pcl

    # For intergroup comparisons, small sample sizes may no significant differences
    # 组间比较，样本量少无差异
    # Backup demo data from HMP (hmp_pathabund.pcl replace to path.pcl)
    # wget -c http://www.imeta.science/github/EasyMetagenome/result/humann2/hmp_pathabund.pcl
    # cp -f hmp_pathabund.pcl result/humann4/path.pcl
    # Set input file 设置输入文件名
    pcl=result/humann4/path.pcl
    # Count the number of rows and columns in the table 7x4789 (统计表格行、列数量)
    csvtk -t stat ${pcl}
    head -n3 ${pcl} | cut -f 1-5
    # For the KW test with grouping, note the grouping column names in the second column 按分组KW检验，注意第二列的分组列名
    humann_associate --input ${pcl} \
        --focal-metadatum Group --focal-type categorical \
        --last-metadatum Group --fdr 0.2 \
        --output result/humann4/associate.txt
    # 4 colume include ID, mean, P-value and Q-value, 322 rows
    csvtk -t stat result/humann4/associate.txt
    head -n5 result/humann4/associate.txt

    # barplot show pathway taxonomic composition:  L-lysine fermentation to acetate and butanoate 
    # 柱状图展示通路的物种组成，如：L-赖氨酸发酵生成乙酸和丁酸
    # Set significant pathway ID from associate.txt，--sort sum metadata 按丰度和分组排序 
    # eg. P163-PWY (P 0.03, Q 0.09)/ 1CMET2-PWY (P 0.12, Q 0.18)
    path=P163-PWY
    grep $path result/humann4/associate.txt
    humann_barplot \
        --input ${pcl} --focal-feature ${path} \
        --focal-metadata Group --last-metadata Group \
        --output result/humann4/barplot_${path}.pdf --sort sum metadata 
    
### KEGG annotation (注释)

    # Support GO, PFAM, eggNOG, level4ec, KEGG, etc. Detail see `humann_regroup_table -h`。

    # regroup gene family into KO(uniref90_ko), options eggNOG(uniref90_eggnog) or EC(uniref90_level4ec)
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do
      humann_regroup_table \
        -i temp/humann4/${i}_2_genefamilies.tsv \
        -g uniref90_ko \
        -o temp/humann4/${i}_ko.tsv
    done
    # Merge sample and correct name (合并并修正样本名)
    humann_join_tables \
      --input temp/humann4/ \
      --file_name ko \
      --output result/humann4/ko.tsv
    sed -i '1s/_Abundance-RPKs//g' result/humann4/ko.tsv
    tail result/humann4/ko.tsv

    # Similar to pathabundance, it can perform operations such as normalization, stratified, and barplot.
    # 与pathabundance类似，可进行标准化renorm、分层stratified、柱状图barplot等操作

    # Stratify into function related species (stratified) and function only (unstratified)
    # 分层为功能包括物种组成和仅功能组成
    humann_split_stratified_table \
      --input result/humann4/ko.tsv \
      --output result/humann4/ 
    wc -l result/humann4/ko*

    # KO to level 1/2/3, 9, 53 and 332 respectively (KO合并为更高层级L3/L2/L1)
    summarizeAbundance.py \
      -i result/humann4/ko_unstratified.tsv \
      -m ${db}/EasyMicrobiome/kegg/KO1-4.txt \
      -c 2,3,4 -s ',+,+,' -n raw --dropkeycolumn \
      -o result/humann4/KEGG
    wc -l result/humann4/KEGG*
    
## 2.2 GraPhlAn taxonomic and phylogenetic trees 高颜值物种或进化树

    # Use export2graphlan to create plotting files
    # 使用export2graphlan制作绘图文件
    conda activate graphlan
    # Detail parameters in PPT or run `export2graphlan.py --help`
    export2graphlan.py --skip_rows 1,2 -i result/metaphlan4/taxonomy.tsv \
      --tree temp/merged_abundance.tree.txt \
      --annotation temp/merged_abundance.annot.txt \
      --most_abundant 100 --abundance_threshold 20 --least_biomarkers 10 \
      --annotations 3,4 --external_annotations 7
    # graphlan annotation
    graphlan_annotate.py --annot temp/merged_abundance.annot.txt \
      temp/merged_abundance.tree.txt  temp/merged_abundance.xml
    # output PDF figure, annoat and legend
    graphlan.py temp/merged_abundance.xml result/metaphlan4/graphlan.pdf --external_legends 


## 2.3 LEfSe Differential analysis (差异分析物种)

    # Set input & output director for different versions (可调目录尝试不同版本)
    # For example, 12 sample examples, replace result to result12 (例如12个样本示例)
    # wget -c http://www.imeta.science/db/EasyMetagenome/result12.zip
    # unzip result12.zip
    result=result

    # Prepare the input file, and change the sample name to the group name (this can be done manually).
    # 准备输入文件，修改样本品为组名(可手动修改)
    # Extract the sample rows and replace them with one row for each sample, then change the ID to SampleID.
    # 提取样本行替换为每个样本一行，修改ID为SampleID
    sed -i 's/\r//g' $result/metaphlan4/taxonomy.tsv
    head -n1 $result/metaphlan4/taxonomy.tsv|tr '\t' '\n'|sed '1 s/ID/SampleID/' > temp/sampleid
    head -n3 temp/sampleid
    # 提取SampleID对应的分组Group(假设为metadata.txt中第二列$2)，替换换行\n为制表符\t，再把行末制表符\t替换回换行
    awk 'BEGIN{OFS=FS="\t"}NR==FNR{a[$1]=$3}NR>FNR{print a[$1]}' \
      $result/metadata.txt temp/sampleid|tr '\n' '\t'|sed 's/\t$/\n/' >temp/groupid
    cat temp/groupid
    sed 's/SampleID/subject_id/' temp/sampleid | tr '\n' '\t'|sed 's/\t$/\n/' > temp/sampleid2
    # 合并分组和数据(替换表头)
    cat temp/groupid temp/sampleid2 <(tail -n+2 $result/metaphlan4/taxonomy.tsv) | grep -v '#' > $result/metaphlan4/lefse.txt
    head -n3 $result/metaphlan4/lefse.txt

    # Method 1. ImageGP 2 https://www.bic.ac.cn/BIC/#/analysis?page=b%27MzY%3D%27&tool_type=tool
    # 方法1. 推荐 https://www.bic.ac.cn/BIC/ 中LEfSe分析
    # Error delete the subject_id line (在线出错，请删除subject_id行)

    # Method 2. LEfSe command line analysis
    # 方法2. LEfSe命令行分析
    # Example：https://github.com/SegataLab/lefse/blob/master/example/bioconda-lefse_run.sh
    conda activate lefse
    result=result
    lefse_run.py -h # LEfSe 1.1.01
    # LEfSe format (转换lefse格式)，s 2  correction for dependent comparison
    lefse_format_input.py $result/metaphlan4/lefse.txt \
      temp/input.in -c 1 -s 2 -o 1000000
    # LEfSe run
    lefse_run.py temp/input.in temp/input.res
    # Plot cladogram (绘制物种树注释差异)
    lefse_plot_cladogram.py temp/input.res \
      $result/metaphlan4/lefse_cladogram.pdf --format pdf
    # Plot features barplot (绘制所有差异特征的柱状图)
    lefse_plot_res.py temp/input.res \
      $result/metaphlan4/lefse_res.pdf --format pdf
    # Draw a bar chart of a single feature (绘制单个特征柱状图)
    # View differences features sorting by abundance (按丰度排序查看显著差异特征)
    grep -v '-' temp/input.res | sort -k3,3n
    # Select a feature to draw, such as Actinobacteria (指定特征绘图，如放线菌)
    lefse_plot_features.py -f one --format pdf \
      --feature_name "k__Bacteria.p__Actinobacteria" \
      temp/input.in temp/input.res \
      $result/metaphlan4/lefse_Actinobacteria.pdf
    # (Optional) Batch plot all difference feature bar charts (可选)批量绘制所有差异特征柱状图
    lefse_plot_features.py -f diff \
      --archive none --format pdf \
      temp/input.in temp/input.res \
      $result/metaphlan4/lefse_

## 2.4 Kraken2+Bracken taxonomic classification and abundance estimation (物种注释和丰度估计)

    # Kraken2 can quickly perform species annotation and quantification at the read level, 
    # and can also perform sequence species annotation at the contig, gene, and metagenomic assembly (MAG/bin) levels.
    # Kraken2可以快速完成读长(read)层面的物种注释和定量，还可以进行重叠群(contig)、基因(gene)、宏基因组组装基因组(MAG/bin)层面的序列物种注释。

    # Start the Kraken2 working environment(启动kraken2工作环境)
    conda activate kraken2
    # Record software version(记录软件版本)
    kraken2 --version # 2.1.6
    mkdir -p temp/kraken2

### Kraken2 taxonomic classification (物种注释)

    # Input(输入): temp/hr/{1}_?.fastq, {1} representative sample name (代表样本名)
    # Database(数据库): -db ${db}/kraken2/pluspf16g/
    # Output(输出结果): temp/kraken2/{1}_report and {1}_output
    # Feature table(物种丰度表): result/kraken2/taxonomy_count.txt 

    # Select a database based on server memory size or specific analytical needs
    # 根据服务器内存大小或具体分析需求选择数据库
    # pluspf16g for small memory / pluspf(100G) for human/animial / pluspfp(214G) for plant/soil
    type=pluspf16g
    # test first sample, 2min
    i=`tail -n+2 result/metadata.txt|cut -f1 | head -n1`
    time kraken2 --db ${db}/kraken2/${type}/ \
      --paired temp/hr/${i}_?.fastq \
      --threads 2 --use-names --report-zero-counts \
      --report temp/kraken2/${i}.report \
      --output temp/kraken2/${i}.output
      # output classified and unclassified reads
      # --unclassified-out "temp/kraken2/${i}.unclassified_reads#.fasta" \
      # --classified-out "temp/kraken2/${i}.classified_reads#.fasta" \
    # Batch processing of multiple samples to generate reports consumes a lot of memory but is fast; therefore, multi-task parallelism is not recommended.
    # 多样本批处理生成report，内存消耗大但速度快，不建议用多任务并行
    for i in `tail -n+3 result/metadata.txt | cut -f1`;do
      kraken2 --db ${db}/kraken2/${type} \
      --paired temp/hr/${i}_?.fastq \
      --threads 2 --use-names --report-zero-counts \
      --report temp/kraken2/${i}.report \
      --output temp/kraken2/${i}.output; done
      
    # Use Krakentools to convert the report to MPA format.
    # 使用krakentools转换report为mpa格式
    for i in `tail -n+2 result/metadata.txt | cut -f1`;do
      kreport2mpa.py -r temp/kraken2/${i}.report \
        --display-header -o temp/kraken2/${i}.mpa; done

    # Display by percentage (optional) 按照百分比展示(可选)
    for i in `tail -n+2 result/metadata.txt | cut -f1`;do
      kreport2mpa.py -r temp/kraken2/${i}.report \
        --percentages --display-header -o temp/kraken2/${i}.p.mpa; done
  
    # Merged samples into a table (合并样本为表格)
    mkdir -p result/kraken2
    # Same row number, sort ensure consistent (结果行数相同sort确保排序一致)
    tail -n+2 result/metadata.txt | cut -f1 | rush -j 1 \
      'tail -n+2 temp/kraken2/{1}.mpa | LC_ALL=C sort | cut -f 2 | sed "1 s/^/{1}\n/" \
      > temp/kraken2/{1}_count '
    # sample1 as header(提取第一样本品行名为表行名)
    tail -n+2 temp/kraken2/`tail -n 1 result/metadata.txt | cut -f 1`.mpa | LC_ALL=C sort | cut -f 1 | \
      sed "1 s/^/Taxonomy\n/" > temp/kraken2/0header_count
    head -n3 temp/kraken2/0header_count
    # paste merge into table (合并样本为表格)
    ls temp/kraken2/*count
    paste temp/kraken2/*count > result/kraken2/tax_count.mpa
    # Check table and statistics (检查表格及统计)
    head -n 5 result/kraken2/tax_count.mpa
    csvtk -t stat result/kraken2/tax_count.mpa

### Bracken abundance estimation (丰度估计)

    # Parameter description (参数简介):
    # -d database, -i input Kraken2 report file
    # -r read length, usually 150, -o outputs the re-estimated abundance
    # -l is the taxonomic level, domain (D), phylum (P), class (C), order (O), family (F), genus (G), and species (S) levels
    # -t is the threshold, defaults to 0, larger values result in higher reliability
    # -d为数据库，-i为输入kraken2报告文件
    # r是读长，通常为150，o输出重新估计的值
    # l为分类级，可选域D、门P、纲C、目O、科F、属G、种S级别丰度估计
    # t是阈值，默认为0，越大越可靠

    # Re-estimate the abundance of each sample in a loop. 
    # Please modify the tax and recalculate P and S once each.
    # 循环重新估计每个样品的丰度，请修改tax分别重新计算P和S各1次
    mkdir -p temp/bracken
    # read length (测序数据长度)、
    readLen=150
    # Only those present in 20% of the samples are retained (20%样本中存在才保留)
    prop=0.2
    # Classification is set into D, P, C, O, F, G, S, with commonly used categories being Kingdom (D), Phylum (P), Genus (G), and Species (S).
    # 设置分类级D,P,C,O,F,G,S，常用界D门P和属G种S
    for tax in P G S;do
    # tax=P
    for i in `tail -n+2 result/metadata.txt | cut -f1`;do
        # i=C1
        bracken -d ${db}/kraken2/${type}/ \
          -i temp/kraken2/${i}.report \
          -r ${readLen} -l ${tax} -t 0 \
          -o temp/bracken/${i}.brk \
          -w temp/bracken/${i}.report; done
    # bracken结果合并成表: 需按表头排序，提取第6列reads count，并添加样本名
    bash ${db}/EasyMicrobiome/script/bracken_integration.sh -t ${tax} \
      -i temp/bracken/*.brk \
      -o result/kraken2/bracken.${tax}.txt
    # 需要确认行数一致才能按以下方法合并      
    # wc -l temp/bracken/*.report
    # bracken结果合并成表: 需按表头排序，提取第6列reads count，并添加样本名
    # tail -n+2 result/metadata.txt | cut -f1 | rush -j 1 \
    #   'tail -n+2 temp/bracken/{1}.brk | LC_ALL=C sort | cut -f6 | sed "1 s/^/{1}\n/" \
    #   > temp/bracken/{1}.count'
    # 提取第一样本品行名为表行名
    # h=`tail -n1 result/metadata.txt|cut -f1`
    # tail -n+2 temp/bracken/${h}.brk | LC_ALL=C sort | cut -f1 | \
    #   sed "1 s/^/Taxonomy\n/" > temp/bracken/0header.count
    # 检查文件数，为n+1
    # ls temp/bracken/*count | wc
    # paste合并样本为表格，并删除非零行
    # paste temp/bracken/*count > result/kraken2/bracken.${tax}.txt
    # 统计行列，默认去除表头
    csvtk -t stat result/kraken2/bracken.${tax}.txt
    # 按频率过滤，-r可标准化，-e过滤(microbiome_helper)
    Rscript ${db}/EasyMicrobiome/script/filter_feature_table.R \
      -i result/kraken2/bracken.${tax}.txt \
      -p ${prop} \
      -o result/kraken2/bracken.${tax}.${prop}
    # head result/kraken2/bracken.${tax}.${prop}
    done
    csvtk -t stat result/kraken2/bracken.?.txt result/kraken2/bracken.?.$prop

    # Personalized results filtering, e.g. Chordata  (个性化结果筛选，如脊索动物)
    # Phylum level removal of chordate (humans) 门水平去除脊索动物(人)
    grep 'Chordata' result/kraken2/bracken.P.${prop}
    grep -v 'Chordata' result/kraken2/bracken.P.${prop} > result/kraken2/bracken.P.${prop}-H

    # Remove host contamination by species name, humans as an example: Homo sapiens (按物种名手动去除宿主污染，以人为例)
    grep 'Homo sapiens' result/kraken2/bracken.S.${prop}
    grep -v 'Homo sapiens' result/kraken2/bracken.S.${prop} \
      > result/kraken2/bracken.S.${prop}-H

    # Clean big annotation files for each sequence (清理每条序列的注释大文件)

    /bin/rm -rf temp/kraken2/*.output

### Diversity and Visualization (多样性和可视化)

    # Alpha diversity：Berger Parker’s (BP), Simpson’s (Si), inverse Simpson’s (ISi), Shannon’s (Sh)
    echo -e "SampleID\tBerger Parker\tSimpson\tinverse Simpson\tShannon" > result/kraken2/alpha.txt
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do
        echo -e -n "$i\t" >> result/kraken2/alpha.txt
        for a in BP Si ISi Sh;do
            alpha_diversity.py -f temp/bracken/${i}.brk -a $a | cut -f 2 -d ':' | tr '\n' '\t' >> result/kraken2/alpha.txt
        done
        echo "" >> result/kraken2/alpha.txt
    done
    cat result/kraken2/alpha.txt

    # Beta diversity
    beta_diversity.py -i temp/bracken/*.brk --type bracken > result/kraken2/beta.txt
    cat result/kraken2/beta.txt

    # Krona plot
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do
        kreport2krona.py -r temp/bracken/${i}.report -o temp/bracken/${i}.krona --no-intermediate-ranks
        ktImportText temp/bracken/${i}.krona -o result/kraken2/krona.${i}.html
    done

    # Pavian Sankey diagram (桑基图)：https://fbreitwieser.shinyapps.io/pavian/ 
    # Online visualization: `Upload sample set` (temp/bracken/*.report), supports multiple samples; `Sample` view results; `Configure Sankey` to configure graph styles; `Save Network` to download the graph webpage.
    # 在线可视化:，左侧菜单，Upload sample set (temp/bracken/*.report)，支持多样本同时上传；Sample查看结果，Configure Sankey配置图样式，Save Network下载图网页

    # For diversity/composition visualization, see 3StatPlot.sh (多样性分析/物种组成可视化见3StatPlot.sh)

