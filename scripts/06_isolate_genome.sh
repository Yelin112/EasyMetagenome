[TOC]

# 06 (Optional) Isolate Bacterial Genome Analysis (06可选：单菌基因组分析)

    # Source: extracted from 1Pipeline.sh Section 5
    # Authors(作者): Yong-Xin Liu(刘永鑫), Defeng Bai(白德凤), Tong Chen(陈同) et al.
    # Version(版本): 1.24, 2025/11/22
    # Usage: source config.sh first, then run commands interactively
    # 用法: 先运行 source config.sh，再交互式执行各命令
    source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"
    cd $wd
## 5.1 Fastp quality control (质量控制)

    # Need genome sequencing data to start, 30s/per sample
    mkdir -p temp/qc/ 
    time tail -n+2 result/metadata.txt | cut -f1 | rush -j 2 \
      "time fastp -i seq/{1}_1.fq.gz -I seq/{1}_2.fq.gz \
        -j temp/qc/{1}_fastp.json -h temp/qc/{1}_fastp.html \
        -o temp/qc/{1}_1.fastq -O temp/qc/{1}_2.fastq \
        > temp/qc/{1}.log 2>&1"

## 5.2 metaspades assembly (组装)

    conda activate megahit
    spades.py -v # v3.15.4
    mkdir -p temp/spades result/spades
    # 127 genoms, 1m17s
    time tail -n+2 result/metadata.txt|cut -f1|rush -j 3 \
    	"spades.py --pe1-1 temp/qc/{1}_1.fastq \
    	  --pe1-2 temp/qc/{1}_2.fastq \
    	  -t 16 --isolate --cov-cutoff auto \
    	  -o temp/spades/{1}" 
	
    # Filter sequences > 1k and summarize/statistically analyze them (筛选>1k的序列并汇总、统计)
    time tail -n+2 result/metadata.txt|cut -f1|rush -j 3 \
	  "seqkit seq -m 1000 temp/spades/{1}/contigs.fasta \
	    > temp/spades/{1}.fa"
	  seqkit stat temp/spades/*.fa | sed 's/temp\/spades\///;s/.fa//' > result/spades/stat1k.txt

## 5.3 checkm quality assessment (质量评估)

    # checkm评估质量
    conda activate drep
    checkm # CheckM v1.1.2
  	mkdir -p temp/checkm result/checkm
  	# 127 genoms, 1m17s
  	time checkm lineage_wf -t 8 -x fa temp/spades/ temp/checkm
  	# format checkm jason to tab
  	checkmJason2tsv.R -i temp/checkm/storage/bin_stats_ext.tsv \
  	  -o temp/checkm/bin_stats.txt
      csvtk -t  pretty temp/checkm/bin_stats.txt | less
	
    # (可选)checkm2评估(测试中...)
    conda activate checkm2
  	mkdir -p temp/checkm2
  	time checkm2 predict --threads 8 --input temp/spades/ --output-directory temp/checkm2
	
    # 筛选污染和高质量基因组 >5% contamination and high quailty
  	awk '$5<90 || $10>5' temp/checkm/bin_stats.txt | csvtk -t cut -f 1,5,10,4,9,2 > temp/checkm/contamination5.txt
  	tail -n+2 temp/checkm/contamination5.txt|wc -l 
  	# 筛选高质量用于下游分析 <5% high-quality for down-stream analysis
  	awk '$5>=90 && $10<=5' temp/checkm/bin_stats.txt | csvtk -t cut -f 1,5,10,4,9,2 | sed '1 i ID\tCompleteness\tContamination\tGC\tN50\tsize' > result/checkm/Comp90Cont5.txt
  	tail -n+2 result/checkm/Comp90Cont5.txt|wc -l 
  	# 链接高质量基因组至新目录，单菌完整度通常>99%
  	mkdir -p temp/drep_in/
  	for n in `tail -n+2 result/checkm/Comp90Cont5.txt|cut -f 1`;do
  	  ln temp/spades/${n}.fa temp/drep_in/
  	done


## 5.4 metawarp binning for mixture (混菌分箱)

    # 分箱和提纯binning & refinement
    conda activate metawrap
    mkdir -p temp/binning temp/bin
    time tail -n+2 temp/checkm/contamination5.txt|cut -f1|rush -j 3 \
      "metawrap binning \
        -o temp/binning/{} -t 8 \
        -a temp/spades/{}/contigs.fasta \
        --metabat2 --maxbin2 \
        temp/qc/{}_*.fastq" 
    time tail -n+2 temp/checkm/contamination5.txt|cut -f1|rush -j 15 \
      "metawrap bin_refinement \
      -o temp/bin/{} -t 8 \
      -A temp/binning/{}/metabat2_bins/ \
      -B temp/binning/{}/maxbin2_bins/ \
      -c 50 -x 10"

    # 分箱结果汇总
  	echo -n -e "" > temp/bin/metawrap.stat
  	for m in `tail -n+2 temp/checkm/contamination5.txt|cut -f1`;do
  	  echo ${m} >> temp/bin/metawrap.stat
  	  cut -f1-4,6-7 temp/bin/${m}/metawrap_50_10_bins.stats >> temp/bin/metawrap.stat
  	done
  	# 分箱后的按b1,b2,b3重命名共培养，单菌也可能减少污染
  	for m in `tail -n+2 temp/checkm/contamination5.txt|cut -f1`;do
          c=1
      	for n in `tail -n+2 temp/bin/$m/metawrap_50_10_bins.stats|cut -f 1`;do
      	  cp temp/bin/$m/metawrap_50_10_bins/${n}.fa temp/drep_in/${m}b${c}.fa
      	  ((c++))
  	done
  	done

    # 分箱前后统计比较
    # 如107个测序分箱为352个基因组，共418个基因组
  	tail -n+2 temp/checkm/contamination5.txt|wc -l
  	ls temp/drep_in/*b?.fa | wc -l
  	ls temp/drep_in/*.fa | wc -l
  	# 重建新ID列表，A代表所有，B代表Bin分箱过的单菌
  	ls temp/drep_in/*.fa|cut -f 3 -d '/'|sed 's/.fa//'|sed '1 i ID'|less -S>result/metadataA.txt
  	ls temp/drep_in/*b?.fa|cut -f 3 -d '/'|sed 's/.fa//'|sed '1 i ID'|less -S>result/metadataB.txt

    # 可视化混菌中覆盖度分布，以第一污染菌为例
    mkdir -p temp/cov
    for i in `tail -n+2 temp/checkm/contamination5.txt|cut -f1`;do
    grep '>' temp/drep_in/${i}*|cut -f 3 -d '/'|sed 's/.fa:>NODE//'|cut -f 1,2,4,6 -d '_'|sed 's/_/\t/g'|sed '1i Genome\tContig\tLength\tvalue' > temp/cov/${i}
    sp_scatterplot2.sh -f temp/cov/${i} -X Contig -Y value -c Genome -s Length -O `tail -n+2 temp/cov/${i}|cut -f2|uniq|awk '{print "\""$1"\""}'|tr "\n" ","|sed 's/,$//'` -w 40 -u 12.5
    done


## 5.5 drep redudancy (基因组去冗余)

  	mkdir -p temp/drep95/ temp/drep99/
  	conda activate drep
  	ls temp/drep_in/*.fa|wc -l
  	# 相似度sa 0.99995 去重复, 0.99 株水平, 0.95 种水平
  	dRep dereplicate \
  	  -g temp/drep_in/*.fa \
  	  -sa 0.99 -nc 0.3 -p 16 -comp 50 -con 10 \
  	  temp/drep99
  	ls temp/drep99/dereplicated_genomes/|wc -l
  	dRep dereplicate \
  	  -g temp/drep_in/*.fa \
  	  -sa 0.95 -nc 0.3 -p 16 -comp 50 -con 10 \
  	  temp/drep95
  	# 统计使用基因组数量丢弃stat total used genomes no discard
  	grep 'passed checkM' temp/drep95/log/logger.log|sed 's/[ ][ ]*/ /g'|cut -f 4 -d ' '
  	# 去冗余后数量，418变为49种
  	ls temp/drep95/dereplicated_genomes/|wc -l
  	# 唯一和重复的基因组unique and duplicate genome
  	csvtk cut -f 11 temp/drep95/data_tables/Widb.csv | sort | uniq -c
  	# 整理种列表
  	echo "SampleID" > result/metadataS.txt
  	ls temp/drep95/dereplicated_genomes/|sed 's/\.fa//' >> result/metadataS.txt
  	# 基因组信息genomeInfo.csv 
  	sed 's/,/\t/g;s/.fa//' temp/drep95/data_tables/genomeInfo.csv |sed '1 s/genome/ID/' > result/gtdb_all/genome.txt

    # 非冗余菌定量
    conda activate coverm
    mkdir -p temp/coverm result/coverm
    # (可选)单样本测试, 3min
    i=X001
    time coverm genome --coupled temp/qc/${i}_1.fastq temp/qc/${i}_2.fastq \
      --genome-fasta-directory temp/drep95/dereplicated_genomes/ -x fa \
      -o temp/coverm/${i}.txt -t 32
    cat temp/coverm/${i}.txt
    # 并行计算, 173样本4min
    tail -n+2 result/metadata.txt|cut -f1|rush -j 4 \
      "coverm genome --coupled temp/qc/{}_1.fastq temp/qc/{}_2.fastq \
      --genome-fasta-directory temp/drep95/dereplicated_genomes/ -x fa \
      -o temp/coverm/{}.txt -t 32"
    # 结果合并
    conda activate humann3
    sed -i 's/_1.fastq Relative Abundance (%)//' temp/coverm/*.txt
    humann_join_tables --input temp/coverm \
      --file_name txt \
      --output result/coverm/abundance.tsv    

## 5.6 GTDB taxonomy classification (物种注释)

  	conda activate gtdbtk
  	# 所有基因组注释，400g, 1h, 1T
  	mkdir -p temp/gtdb_all result/gtdb_all
  	memusg -t gtdbtk classify_wf \
  	  --genome_dir temp/drep_in/ \
  	  --out_dir temp/gtdb_all/ \
        --extension fa --skip_ani_screen \
        --prefix tax \
        --cpus 16
      
  	# 95%聚类种基因组注释，40g, 1h, 500G
  	mkdir -p temp/gtdb_95 result/gtdb_95
  	# Taxonomy classify 
  	gtdbtk classify_wf \
  	  --genome_dir temp/drep95/dereplicated_genomes/ \
  	  --out_dir temp/gtdb_95 \
        --extension fa --skip_ani_screen \
        --prefix tax \
        --cpus 8
  	# Phylogenetic tree infer
  	gtdbtk infer \
  	  --msa_file temp/gtdb_95/align/tax.bac120.user_msa.fasta.gz \
  	  --out_dir temp/gtdb_95 \
  	  --cpus 8 --prefix g >> temp/gtdb_95/infer.log 2>&1
  	ln `pwd`/temp/gtdb_95/infer/intermediate_results/g.unrooted.tree result/gtdb_95/
  
  	# 细菌format to standard 7 levels taxonomy 
  	tail -n+2 temp/gtdb_95/classify/tax.bac120.summary.tsv|cut -f 1-2|sed 's/;/\t/g'|sed '1 s/^/ID\tKingdom\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\n/' > result/gtdb_95/tax.bac.txt
  	# 古菌(可选)
  	tail -n+2 temp/gtdb_95/classify/tax.ar122.summary.tsv|cut -f 1-2|sed 's/;/\t/g'|sed '1 s/^/ID\tKingdom\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\n/' > result/gtdb_95/tax.ar.txt
  	cat result/gtdb_95/tax.bac.txt <(tail -n+2 result/gtdb_95/tax.ar.txt) > result/gtdb_95/tax.txt
  	
  	# Widb.csv 非冗余基因组信息
  	sed 's/,/\t/g;s/.fa//' temp/drep95/data_tables/Widb.csv|cut -f 1-7,11|sed '1 s/genome/ID/' > result/gtdb_95/genome.txt
  	# 整合物种注释和基因组信息 Integrated taxonomy and genomic info 
  	awk 'BEGIN{OFS=FS="\t"} NR==FNR{a[$1]=$0} NR>FNR{print $0,a[$1]}' result/gtdb_95/genome.txt result/gtdb_95/tax.txt|cut -f 1-8,10- > result/gtdb_95/annotation.txt
  	# csvtk -t headers -v result/gtdb_95/annotation.txt
	
  	# 制作itol files
  	cd result/gtdb_95
  	table2itol.R -D plan1 -a -c double -i ID -l Genus -t %s -w 0.5 annotation.txt
  	table2itol.R -D plan2 -a -d -c none -b Phylum -i ID -l Genus -t %s -w 0.5 annotation.txt
  	table2itol.R -D plan3 -c keep -i ID -t %s annotation.txt
  	table2itol.R -D plan4 -a -c factor -i ID -l Genus -t %s -w 0 annotation.txt
  	# Stat each level
  	echo -e 'Taxonomy\tKnown\tNew' > tax.stat
  	for i in `seq 2 8`;do
  	  head -n1 tax.txt|cut -f ${i}|tr '\n' '\t' >> tax.stat
  	  tail -n+2 tax.txt|cut -f ${i}|grep -v '__$'|sort|uniq -c|wc -l|tr '\n' '\t' >> tax.stat
  	  tail -n+2 tax.txt|cut -f ${i}|grep '__$'|wc -l >> tax.stat; done
  	cat tax.stat
  	tail -n+2 tax.txt|cut -f3|sort|uniq -c|awk '{print $2"\t"$1}'|sort -k2,2nr > count.phylum
  	cat count.phylum
  	cd ../..

## 5.7 Functional annotation by eggnog/dbcan/arg/antismash

    ## 基因注释
  	mkdir -p temp/prodigal
  	conda activate eggnog
      prodigal -v # V2.6.3
      # 50g, 31s, 4m
      time tail -n+2 result/metadataS.txt|cut -f1|rush -j 10 \
  	"prodigal \
  	  -i temp/drep95/dereplicated_genomes/{1}.fa \
  	  -o temp/prodigal/{1}.gff  \
  	  -a temp/prodigal/{1}.faa \
  	  -d temp/prodigal/{1}.ffn \
  	  -p single -f gff" 
  	seqkit stat temp/prodigal/*.ffn | sed 's/temp\/prodigal\///;s/\.ffn//;s/[[:blank:]]\{1,\}/\t/g' | cut -f 1,3-  \
  	  > result/prodigal.txt

    # 碳水化合物注释
    mkdir -p temp/dbcan3 result/dbcan3
    time tail -n+2 result/metadataS.txt|cut -f1|rush -j 9 \
  	"diamond blastp \
  	  --db ${db}/dbcan3/CAZyDB \
  	  --query temp/prodigal/{1}.faa \
  	  --outfmt 6 --threads 8 --quiet --log \
  	  --evalue 1e-102 --max-target-seqs 1 --sensitive \
  	  --block-size 6 --index-chunks 1 \
  	  --out temp/dbcan3/{1}_diamond.f6"
  	wc -l temp/dbcan3/*.f6|head -n-1|awk '{print $2"\t"$1}'|cut -f3 -d '/'|sed 's/_diamond.f6//'|sed '1 i ID\tCAZy'|less -S > result/dbcan3/gene.count
  	# format blast2genelist
  	for i in `tail -n+2 result/metadataS.txt|cut -f1`;do
  	format_dbcan3list.pl \
  	  -i temp/dbcan3/${i}_diamond.f6 \
  	  -o temp/dbcan3/${i}.list
  	done
  	# CAZy type count
  	for i in `tail -n+2 result/metadataS.txt|cut -f1`;do
  	  tail -n+2 temp/dbcan3/${i}.list|cut -f2|sort|uniq -c|awk '{print $2"\t"$1}'|sed "1 i CAZy\t${i}"|less -S > temp/dbcan3/${i}_CAZy.tsv
  	done
  	# merge2table
  	conda activate humann3
  	humann_join_tables \
  	  --input temp/dbcan3/ --file_name CAZy \
  	  --output result/dbcan3/cazy.txt
  	csvtk -t stat result/dbcan3/cazy.txt
  	# merge to level1
  	paste <(cut -f1 result/dbcan3/cazy.txt) <(cut -f1 result/dbcan3/cazy.txt|tr '0-9' ' '|sed 's/ //g') | sed '1 s/\tCAZy/\tLevel1/' >  result/dbcan3/cazy.L1
  	summarizeAbundance.py \
  	  -i result/dbcan3/cazy.txt \
  	  -m result/dbcan3/cazy.L1 \
  	  -c 2 -s ',' -n raw  --dropkeycolumn \
  	  -o result/dbcan3/sum
  	# 基因相似度
  	echo -e 'Name\tCAZy\tIdentity\tGenome' > result/dbcan3/identity.txt
  	for i in `tail -n+2 result/metadataS.txt|cut -f1`;do
  	  csvtk -t replace -f 2 -p "\d+" -r "" temp/dbcan3/${i}.list | uniq | tail -n+2 | sed "s/$/\t${i}/" >> result/dbcan3/identity.txt
  	done
  	csvtk -t stat result/dbcan3/identity.txt
  	sp_boxplot.sh -f result/dbcan3/identity.txt -m T -F CAZy -d Identity

    # 耐药基因
  	mkdir -p temp/card result/card
    conda activate rgi6
    # load database 加载数据库
    rgi load -i ${db}/card/card.json \
    	--card_annotation ${db}/card/card.fasta --local
    	# Annotation 蛋白注释
    	# 默认为0, --include_loose 可极大增加结果，519/4657=11.14%;  --exclude_nudge结果不变，但jason为空
    time for i in `tail -n+2 result/metadataS.txt|cut -f1`;do
    	# i=X004b2
    	cut -f 1 -d ' ' temp/prodigal/${i}.faa | sed 's/\*//' > temp/prodigal/protein_${i}.fa
    	rgi main \
    	--input_sequence temp/prodigal/protein_${i}.fa \
    	--output_file temp/card/${i} \
    	--input_type protein --clean \
    	--num_threads 8 --alignment_tool DIAMOND > temp/log 2>&1
    done

    mkdir -p temp/ARG
    for FILE in temp/card/*.txt; do
    # 获取文件名的基本部分
    BASENAME=$(basename "$FILE")
    OUTPUT="temp/ARG/${BASENAME}"

    # 提取第1列，第17列和第28列，并写入对应的输出文件
    awk -F'\t' -v OFS='\t' 'BEGIN {print "ORF_ID"} NR>1 {print $1}' "$FILE" > "$OUTPUT"
    done

    # 处理每个输出文件
    for file in temp/ARG/*.txt; do
        # 去掉回车符并更新文件
        awk -v fname="${file%.txt}" 'BEGIN {FS=OFS="\t"} {gsub(/\r/, ""); if (NR==1) print $0, fname; else print $1, $2, 1}' "$file" > "${file%.txt}_updated.txt"
        echo "$file 处理完成"
    done

    mkdir -p temp/ARG_updated
    mv temp/ARG/*updated.txt temp/ARG_updated
    # merge2table
    conda activate humann3
    humann_join_tables \
      --input temp/ARG_updated/ --file_name Mx_All \
      --output temp/ARG_updated/ARG.tsv
    sed -i 's/\t\t/\t1\t/g; s/\t$/\t1/' temp/ARG_updated/ARG.tsv
    
    mkdir -p temp/ARG2
    # 获取ORF_ID对应的基因和抗生素注释
    for FILE in temp/card/*.txt; do
        # 获取文件名的基本部分
        BASENAME=$(basename "$FILE")
        OUTPUT="temp/ARG2/${BASENAME}"
        # 提取第17列和第28列，并写入对应的输出文件
        awk -F'\t' -v OFS='\t' 'BEGIN {print "ORF_ID", "AMR_Gene_Family", "Antibiotic"} NR>1 {print $1, $17, $28}' "$FILE" > "$OUTPUT"
    done
    
    for FILE in temp/card/*.txt; do
        # 获取文件名的基本部分
        BASENAME=$(basename "$FILE")
        OUTPUT="temp/ARG2/${BASENAME}"
        # 提取第17列和第28列，并写入对应的输出文件
        awk -F'\t' -v OFS='\t' 'NR>1 {print $1, $17, $28}' "$FILE" > "$OUTPUT"
    done
    cat temp/ARG2/*.txt > temp/ARG2/annotation.txt
    echo -e "ORF_ID\tAMR_Gene_Family\tAntibiotic\n$(cat temp/ARG2/annotation.txt)" > temp/ARG2/annotation.txt
    
    #排序ORF_ID列，合并ARG2/annotation.txt和ARG/updated/ARG.txt,保存为ARG_final.tsv
    sed -n '1p' temp/ARG_updated/ARG.tsv > temp/ARG_updated/sorted_ARG.tsv
    sed -n '1!p' temp/ARG_updated/ARG.tsv | sort -k1,1 >> temp/ARG_updated/sorted_ARG.tsv
    sed -n '1p' temp/ARG2/annotation.txt > temp/ARG2/sorted_annotation.txt
    sed -n '1!p' temp/ARG2/annotation.txt | sort -k1,1 >> temp/ARG2/sorted_annotation.txt
    join -t $'\t' -1 1 -2 1 temp/ARG_updated/sorted_ARG.tsv temp/ARG2/sorted_annotation.txt > temp/ARG2/ARG_final.tsv

