[TOC]

# 04 Assembly-based Analysis (04组装分析)

    # Source: extracted from 1Pipeline.sh Section 3
    # Authors(作者): Yong-Xin Liu(刘永鑫), Defeng Bai(白德凤), Tong Chen(陈同) et al.
    # Version(版本): 1.24, 2025/11/22
    # Usage: source config.sh first, then run commands interactively
    # 用法: 先运行 source config.sh，再交互式执行各命令
    source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"
    cd $wd
##  3.1 Assemble (组装)

    # Start working environment (启动工作环境)
    conda activate megahit
    
### MEGAHIT Assembly (组装)

    # Delete directory for rerun (删除旧文件夹才能重新运行)
    # /bin/rm -rf temp/megahit
    # Assembly，demo 3p 80m, TB may n days (TB数据要几天)
    megahit -v # MEGAHIT v1.2.9
    /usr/bin/time -v megahit -t 3 \
        -1 `tail -n+2 result/metadata.txt|cut -f1|sed 's/^/temp\/hr\//;s/$/_1.fastq/'|tr '\n' ','|sed 's/,$//'` \
        -2 `tail -n+2 result/metadata.txt|cut -f1|sed 's/^/temp\/hr\//;s/$/_2.fastq/'|tr '\n' ','|sed 's/,$//'` \
        -o temp/megahit 
    # Stat contig size, 160M, eg. 18sample 100G data 10h contigs 1.8G
    # If too many contigs, filter by length to reduce data and improve gene integrity. See appendix megahit
    # 如果contigs太多，可以按长度筛选，降低数据量，提高基因完整度，详见附录megahit
    seqkit stat temp/megahit/final.contigs.fa
    # Preview first 6 rows and 60 characters each line (预览重叠群最前6行，前60列字符)
    head -n6 temp/megahit/final.contigs.fa | cut -c1-60
    # Delete temporary files (删除临时文件)
    /bin/rm -rf temp/megahit/intermediate_contigs

### metaSPAdes fine assembly (option) 精细组装(可选) 

    # More time and memory consume (精细但使用内存和时间更多)
    mkdir -p temp/metaspades
    /usr/bin/time -v -o metaspades.py.log metaspades.py -t 3 -m 100 \
      `tail -n+2 result/metadata.txt|cut -f1|sed 's/^/temp\/hr\//;s/$/_1.fastq/'|sed 's/^/-1 /'| tr '\n' ' '` \
      `tail -n+2 result/metadata.txt|cut -f1|sed 's/^/temp\/hr\//;s/$/_2.fastq/'|sed 's/^/-2 /'| tr '\n' ' '` \
      -o temp/metaspades
    # View calculate time (Elapsed time, 2.5h) and Memory consume (Maximum resident set size, 22G)
    cat metaspades.py.log
    # 219M，contigs bigger than megahit
    ls -sh temp/metaspades/contigs.fasta
    seqkit stat temp/metaspades/contigs.fasta
    # Select VIP result, Delete temporary files (删除临时文件)
    mv temp/metaspades/contigs.fasta temp/metaspades.fa
    /bin/rm -rf temp/metaspades/

    # Note: metaSPAdes supports hybrid assembly of second and third generation systems (see appendix). 
    # Additionally, there are OPERA-MS assembly solutions for second and third generation systems.
    # 注：metaSPAdes支持二、三代混合组装，见附录，此外还有OPERA-MS组装二、三代方案

### QUAST assembly evaluation (组装评估)

    mkdir -p result/megahit

    # QUAST evaluation, generating reports in various formats such as tsv/txt text, html webpage, and PDF.
    # QUAST评估，生成report文本tsv/txt、网页html、PDF等格式报告
    quast.py temp/megahit/final.contigs.fa \
      -o result/megahit/quast -t 2

    # (opt) megahit versus metaspades
    quast.py --label "megahit,metapasdes" \
        temp/megahit/final.contigs.fa \
        temp/metaspades.fa \
        -o result/quast

    # (opt)metaquast access (更全面评估，需下载相关数据库受网速影响可能时间很长或失败)
    # metaquast based on silva, and top 50 species genome, 18min
    time metaquast.py temp/megahit/final.contigs.fa \
      -o result/megahit/metaquast

## 3.2 Gene prediction, cluster & quantitfy(基因预测、去冗余和定量)

### metaProdigal Gene prediction (基因预测)

    # Input file: Assembled sequences temp/megahit/final.contigs.fa
    # Output file: Gene sequence predicted by prodigal temp/prodigal/gene.fa
    # For large gene sequences, refer to the appendix for prodigal gene file splitting and parallel computation.
    # 输入文件：组装的序列 result/megahit/final.contigs.fa
    # 输出文件：prodigal预测的基因序列 temp/prodigal/gene.fa
    # 基因大，可参考附录prodigal拆分基因文件，并行计算

    mkdir -p temp/prodigal
    # prodigal meta mode, 8m, > and 2>&1 record gene.log, ~1G 1h
    time prodigal -i temp/megahit/final.contigs.fa \
        -d temp/prodigal/gene.fa \
        -o temp/prodigal/gene.gff \
        -p meta -f gff > temp/prodigal/gene.log 2>&1 
    # Check if the log has completed (查看日志是否运行完成)
    tail temp/prodigal/gene.log
    # Count of genes (基因数量) 261K, 6G18s3M
    seqkit stat temp/prodigal/gene.fa 
    # Count complete genes, if the data volume is large, select complete gene, 73K
    # 统计完整基因数量，数据量大可只用完整基因部分
    grep -c 'partial=00' temp/prodigal/gene.fa 
    # Select complete gene (提取完整基因)
    seqkit grep -n -r -p "partial=00" temp/prodigal/gene.fa > temp/prodigal/full_length.fa
    seqkit stat temp/prodigal/full_length.fa
    
    # Opt. Single sample assemble bacth run (可选单样本组装可批量运行)
    for i in `tail -n+2 result/metadata.txt | cut -f1`;do
    	mkdir -p temp/prodigal/${i}/
    	prodigal -i result/megahit/${i}/final.contigs.fa \
            -d temp/prodigal/${i}/gene.fa \
            -o temp/prodigal/${i}/gene.gff \
            -p meta -f gff > temp/prodigal/${i}/gene.log 2>&1 
    done

### cd-hit cluster & redundancy (基因聚类/去冗余)

    # Input file: gene sequences predicted by prodigal temp/prodigal/gene.fa
    # Output files: Deredundant gene and protein sequences: result/NR/nucleotide.fa, result/NR/protein.fa
    # 输入文件：prodigal预测的基因序列 temp/prodigal/gene.fa
    # 输出文件：去冗余后的基因和蛋白序列：result/NR/nucleotide.fa, result/NR/protein.fa

    mkdir -p result/NR
    # aS coverage, c similarity, G local alignment, g optimal solution, T multithreading, M memory 0 unlimited
    # aS覆盖度，c相似度，G局部比对，g最优解，T多线程，M内存0不限制
    # 2M 384p 8m，3M384p15m，2千万需要2000h，多线程可加速
    time cd-hit-est -i temp/prodigal/gene.fa \
        -o result/NR/nucleotide.fa \
        -aS 0.9 -c 0.95 -G 0 -g 0 -T 0 -M 0
    # Counting the number of non-redundant genes, the number of genes in a single assembly does not decrease significantly, such as 3M-2M. Multiple batch assemblies show high redundancy.
    # 统计非冗余基因数量，单次拼接结果数量下降不大，如3M-2M，多批拼接冗余度高
    grep -c '>' result/NR/nucleotide.fa
    # Translate nucleic acids into corresponding protein sequences, and use `--trim` to remove trailing asterisks.
    # 翻译核酸为对应蛋白序列, --trim去除结尾的*
    seqkit translate --trim result/NR/nucleotide.fa \
        > result/NR/protein.fa 
    # Redundancy removal for both batches of data was accelerated using cd-hit-est-2d, see appendix.
    # 两批数据去冗余使用cd-hit-est-2d加速，见附录
    
    # batch samples (样本批量运行)
    for i in `tail -n+2 result/metadata.txt | cut -f1`;do
    	mkdir -p result/NR/${i}
        cd-hit-est -i temp/prodigal/${i}/gene.fa \
            -o result/NR/${i}/nucleotide.fa \
            -aS 0.9 -c 0.95 -G 0 -g 0 -T 0 -M 0
        grep -c '>' result/NR/${i}/nucleotide.fa
        seqkit translate --trim result/NR/${i}/nucleotide.fa \
            > result/NR/${i}/protein.fa 
    done

### salmon quantitfy (基因定量)

    # Input file: Redundancy-free gene sequence: result/NR/nucleotide.fa
    # Output file: Salmon quantification: result/salmon/gene.count, gene.TPM
    # 输入文件：去冗余后的基因序列：result/NR/nucleotide.fa
    # 输出文件：Salmon定量：result/salmon/gene.count, gene.TPM

    mkdir -p temp/salmon
    salmon -v # 1.10.3

    # build index, -t sequence, -i index (建索引, -t序列, -i 索引, 2m)
    time salmon index -t result/NR/nucleotide.fa \
      -p 3 -i temp/salmon/index 

    # Quantitative: -l automatic library type selection, p threads, --meta metagenomics
    # 定量，l文库类型自动选择，p线程，--meta宏基因组, 10s
    i=C1
    time salmon quant -i temp/salmon/index -l A -p 3 --meta \
        -1 temp/hr/${i}_1.fastq -2 temp/hr/${i}_2.fastq \
        -o temp/salmon/${i}.quant
    # parallel, 1m, 18 samples 30m
    time tail -n+2 result/metadata.txt | cut -f1 | rush -j 2 \
      "salmon quant -i temp/salmon/index -l A -p 3 --meta \
        -1 temp/hr/{1}_1.fastq -2 temp/hr/{1}_2.fastq \
        -o temp/salmon/{1}.quant"

    # Merge (合并)
    mkdir -p result/salmon
    salmon quantmerge --quants temp/salmon/*.quant \
        -o result/salmon/gene.TPM
    salmon quantmerge --quants temp/salmon/*.quant \
        --column NumReads -o result/salmon/gene.count
    sed -i '1 s/.quant//g' result/salmon/gene.*
    # Preview (预览结果)
    head -n3 result/salmon/gene.*

## 3.3 Functional gene annotation (功能基因注释)

    # input：result/NR/protein.fa
    # COG: result/eggnog/cogtab.count
    #      result/eggnog/cogtab.count.spf (for STAMP)
    # KO table：result/eggnog/kotab.count
    # CAZy Carbohydrate：result/dbcan3/cazytab.count
    # Expanded to other databases (可拓展其它数据库)

### eggNOG gene annotation(COG/KEGG/CAZy基因注释)

    # eggNOG: https://github.com/eggnogdb/eggnog-mapper
    # Run and record the software version (运行并记录软件版本)
    conda activate eggnog
    emapper.py --version
    mkdir -p temp/eggnog
    # emapper-2.1.7 / Expected eggNOG DB version: 5.0.2 / diamond version 2.0.15

    # run emapper, 3p 100m, default diamond 1e-3; 2M,32p,1.5h
    time emapper.py --data_dir ${db}/eggnog \
      -i result/NR/protein.fa --cpu 3 -m diamond --override \
      -o temp/eggnog/output

    # Format the results and display the table headers (格式化结果并显示表头)
    grep -v '^##' temp/eggnog/output.emapper.annotations | sed '1 s/^#//' \
      > temp/eggnog/output
    csvtk -t headers -v temp/eggnog/output

    # create COG/KO/CAZy abundance table
    mkdir -p result/eggnog
    # Show help (显示帮助)
    summarizeAbundance.py -h
    # Summary, the 7 columns COG_category are alphabetically separated, and the 12 columns KEGG_ko and 19 columns CAZy are comma-separated. The original values are summed.
    # 汇总，7列COG_category按字母分隔，12列KEGG_ko和19列CAZy按逗号分隔，原始值累加
    summarizeAbundance.py \
      -i result/salmon/gene.TPM \
      -m temp/eggnog/output --dropkeycolumn \
      -c '7,12,19' -s '*+,+,' -n raw \
      -o result/eggnog/eggnog
    sed -i 's#^ko:##' result/eggnog/eggnog.KEGG_ko.raw.txt
    sed -i '/^-/d' result/eggnog/eggnog*
    head -n3 result/eggnog/eggnog*
    # eggnog.CAZy.raw.txt  eggnog.COG_category.raw.txt  eggnog.KEGG_ko.raw.txt

    # format to STAMP spf format
    awk 'BEGIN{FS=OFS="\t"} NR==FNR{a[$1]=$2} NR>FNR{print a[$1],$0}' \
      ${db}/EasyMicrobiome/kegg/KO_description.txt \
      result/eggnog/eggnog.KEGG_ko.raw.txt | \
      sed 's/^\t/Unannotated\t/' \
      > result/eggnog/eggnog.KEGG_ko.TPM.spf
    head -n 5 result/eggnog/eggnog.KEGG_ko.TPM.spf
    # KO to level 1/2/3
    summarizeAbundance.py \
      -i result/eggnog/eggnog.KEGG_ko.raw.txt \
      -m ${db}/EasyMicrobiome/kegg/KO1-4.txt \
      -c 2,3,4 -s ',+,+,' -n raw --dropkeycolumn \
      -o result/eggnog/KEGG
    head -n3 result/eggnog/KEGG*
    
    # CAZy
    awk 'BEGIN{FS=OFS="\t"} NR==FNR{a[$1]=$2} NR>FNR{print a[$1],$0}' \
       ${db}/EasyMicrobiome/dbcan2/CAZy_description.txt result/eggnog/eggnog.CAZy.raw.txt | \
      sed 's/^\t/Unannotated\t/' > result/eggnog/eggnog.CAZy.TPM.spf
    head -n 3 result/eggnog/eggnog.CAZy.TPM.spf
    
    # COG
    awk 'BEGIN{FS=OFS="\t"} NR==FNR{a[$1]=$2"\t"$3} NR>FNR{print a[$1],$0}' \
      ${db}/EasyMicrobiome/eggnog/COG.anno result/eggnog/eggnog.COG_category.raw.txt > \
      result/eggnog/eggnog.COG_category.TPM.spf
    head -n 3 result/eggnog/eggnog.COG_category.TPM.spf

### CARD耐药基因

    # CARD: https://card.mcmaster.ca/ 
    # GitHub: https://github.com/arpcard/rgi
    # Result：protein.json, upload to CARD; protein.txt, annotation list
    mkdir -p result/card
    conda activate rgi
    rgi main -v # 6.0.5
    # Simplified Protein ID (简化蛋白ID)
    cut -f 1 -d ' ' result/NR/protein.fa > temp/protein.fa
    grep '>' result/NR/protein.fa | head -n 3
    grep '>' temp/protein.fa | head -n 3
    
    # Protein-level annotation ARG
    # rgi load -i $db/card/card.json --card_annotation $db/card/card.fasta
    time rgi main -i temp/protein.fa -t protein \
      -n 9 -a DIAMOND --include_loose --clean \
      -o result/card/protein
    head -n3 result/card/protein.txt
    # WARNING baeR ---> hsp.bits: 140.6 <class 'float'> ? <class 'str'>  Exception : <class 'KeyError'> -> '2885' -> Model(2885) missing in database. Please generate new database.
    # Software and database have bugs that do not affect the results (新版软件与数据库bug，不影响主体结果)
    
    # (Optional) Gene-level annotation ARG (可选)基因层面注释ARG 
    cut -f 1 -d ' ' result/NR/nucleotide.fa > temp/nucleotide.fa
    grep '>' temp/nucleotide.fa | head -n3
    rgi main -i temp/nucleotide.fa -t contig \
      -n 9 -a DIAMOND --include_loose --clean \
      -o result/card/nucleotide
    head -n3 result/card/nucleotide.txt
    
    # (Optional) Overlap Contigs Level Annotation (ARG) (可选)重叠群层面注释ARG
    cut -f 1 -d ' ' temp/megahit/final.contigs.fa > temp/contigs.fa
    grep '>' temp/contigs.fa | head -n3
    time rgi main -i temp/contigs.fa -t contig \
      -n 9 -a DIAMOND --include_loose --clean \
      -o result/card/contigs
    head result/card/contigs.txt

## 3.4 Kraken2 gene taxonomic annotation (基因物种注释)

    # Generate report in default taxid output
    conda activate kraken2
    # 16g 60.69%, pf 73.02%, pfp 74.20%
    kraken2 --db ${db}/kraken2/pluspf16g \
      result/NR/nucleotide.fa \
      --threads 3 \
      --report temp/NRgene.report \
      --output temp/NRgene.output
    # Genes & taxid list
    grep '^C' temp/NRgene.output | cut -f 2,3 | sed '1 i Name\ttaxid' \
      > temp/NRgene.taxid
    # Add taxonomy
    awk 'BEGIN{FS=OFS="\t"} NR==FNR{a[$1]=$0} NR>FNR{print $1,a[$2]}' \
      $db/EasyMicrobiome/kraken2/taxonomy.txt \
      temp/NRgene.taxid > result/NR/nucleotide.tax
    conda activate eggnog 
    summarizeAbundance.py \
      -i result/salmon/gene.TPM \
      -m result/NR/nucleotide.tax  --dropkeycolumn \
      -c '2,3,4,5,6,7,8,9' -s ',+,+,+,+,+,+,+,' -n raw \
      -o result/NR/tax
    wc -l result/NR/tax*|sort -n

