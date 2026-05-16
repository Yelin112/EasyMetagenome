[TOC]

# 07 (Optional) Pan-genome Analysis (07可选：泛基因组分析)

    # Source: extracted from 1Pipeline.sh Section 6
    # Authors(作者): Yong-Xin Liu(刘永鑫), Defeng Bai(白德凤), Tong Chen(陈同) et al.
    # Version(版本): 1.24, 2025/11/22
    # Usage: source config.sh first, then run commands interactively
    # 用法: 先运行 source config.sh，再交互式执行各命令
    source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"
    # ★ MODIFY: edit config.sh to set soft/db/wd and analysis parameters before running
    # ★ 修改: 在 config.sh 中设置路径和分析参数，此处无需改动
    cd $wd
利用宏基因组测序数据进行泛基因组分析，首先需要确定要分析泛基因组的对象，比如Alistipes属或者Alistipes putredinis菌种，这里的流程以Alistipes putredinis为例进行泛基因组数据的挖掘分析

## 6.1 Download genome from NCBI (下载基因组)

    # 从NCBI上获取assembly_summary_refseq.txt文件
    mkdir -p temp/metapangenome
    cd temp/metapangenome
    wget -c https://ftp.ncbi.nlm.nih.gov/genomes/refseq/assembly_summary_refseq.txt

    assemblyFile="assembly_summary_refseq.txt"
    taxa="Alistipes_putredinis"
    taxDir="Alistipes_putredinis"

    mkdir ncbi_genomes
    mkdir ncbi_genomes/$taxDir

    for taxon in $taxa; do
    taxonSafe=$(echo $taxon | tr ' ' '_')
    taxonGrep=$(echo $taxon | tr '_' ' ')
    # 基因组ftp地址
    ftpDir=$(grep "$taxonGrep" $assemblyFile | awk -F"\t" '{print $20}')
    cd ncbi_genomes/$taxDir

    for dirPath in $ftpDir; do
    # 获取ID
    genomeID=$(echo "$dirPath" | sed 's/^.*\///g')
    # 获取基因组链接
    ftpPath="$dirPath/${genomeID}_genomic.fna.gz"
    # 重命名
    friendlyName=$(grep "$genomeID" ../../$assemblyFile | awk -F"\t" '{print $8}' | awk '{print $1 FS $2}' | tr -d '_,.-' | sed -E 's/^(.)[A-z0-9]* ([A-z0-9]{2}).*$/\1\2/')
    deflineName=$(grep "$genomeID" ../../$assemblyFile | awk -F"\t" '{print $8 " " $9}' | sed 's/strain=//' | tr ' -' '_' | tr -d '/=(),.')
    genomeID="${friendlyName}_$genomeID"
    # 下载并解压
    wget $ftpPath -O $genomeID.fa.gz
    gunzip $genomeID.fa.gz
    # 序列信息重命名
    awk -v defline="$deflineName" '/^>/{print ">" defline "_ctg" (++i)}!/^>/' $genomeID.fa >> temp.txt
    mv temp.txt $genomeID.fa
    done
    done

    # 加入自有数据得到的对应细菌基因组
    # 非冗余基因组集位置：temp/drep95/dereplicated_genomes/*.fa
    # 非冗余基因组分类信息位置：temp/gtdb_classify
    # 需要根据分类信息找到分析物种或类群的基因组，然后与NCBI下载的基因组文件合并为1个文件
    cp temp/drep95/dereplicated_genomes/Mx_All_55.fa ./ncbi_genomes/Alistipes_putredinis/Mx_All_55.fa
    cp ./ncbi_genomes/Alistipes_putredinis/Mx_All_55.fa ./ncbi_genomes/Alistipes_putredinis/Mx_All_55.fna

    # 由于每一个基因组文件里面包含多条序列，需要将多条序列合并为1条
    # Directory containing the files
    input_dir="ncbi_genomes/Alistipes_putredinis/"

    # 循环处理每一个fna文件
    for file in "$input_dir"/*.fna; do
      filename=$(basename "$file")
      output_file="${file%.fna}_merged_sequence.fna"
      awk '/^>/{if (seqlen){print seq} if (NR==1){print} seq=""; seqlen=0; next} {seq=seq $0; seqlen+=length($0)} END{print seq}' "$file" > "$output_file"
    done

    # 合并NCBI下载多个基因组文件并修改格式
    cat "$input_dir"/*merged_sequence.fna > $species-isolates.fa

    ## 获取fa文件的head信息
    conda activate anvio-8
    grep '^>' Alistipes-putredinis-isolates.fa > headers01.txt
    ## 在开始时清理 contig 文件中的 fasta序列的head信息，以确保下游操作顺利进行
    species="Alistipes-putredinis"
    anvi-script-reformat-fasta -o $species-isolates-CLEAN.fa -l 1000 \
                  --simplify-names \
                  -r $species-isolates-contigIDs.txt $species-isolates.fa
    mv $species-isolates-CLEAN.fa $species-isolates.fa

## 6.2 CONTIGS library 建立序列库

    # 建立Alistipes-putredinis-isolates-CONTIGS库
    anvi-gen-contigs-database -f $species-isolates.fa -n Alistipes \
                  -o $species-isolates-CONTIGS.db \
                  --split-length 1500000 \
                  --num-threads 24
    ## 从 hmm 集合中获取细菌单拷贝基因 16S 信息
    anvi-run-hmms -c $species-isolates-CONTIGS.db \
                  --num-threads 24
    
    ## 安装ncbi-cogs用于功能注释
    anvi-setup-ncbi-cogs -T 24 --just-do-it --reset
    
    ## COGs功能注释
    anvi-run-ncbi-cogs -c $species-isolates-CONTIGS.db --search-with blastp -T 24
    
    ## 导出注释得到的功能数据表
    # 如果没有进行COGs功能注释，可跳过该步骤
    touch ncbi-cogs-results-fmt-$species-isolates01.tsv
    anvi-import-functions -c $species-isolates-CONTIGS.db \
                  -i ncbi-cogs-results-fmt-$species-isolates01.tsv
    
    ## 建议映射             
    bowtie2-build $species-isolates.fa $species-isolates
    
    ## 使用 bowtie2和默认参数（“--sensitive”），将宏基因组匹配到 contigs 数据库中的contigs上
    prefix="$species-isolates"
    ## 单样本处理示例，其它样本相同
    bowtie2 -x $prefix -1 /temp/hr2/FC1_1.fastq -2 \
                  /temp/hr2/FC1_2.fastq --no-unal \
                  --threads 24 | samtools view -b - | samtools sort -@ 12 - > bt_mapped_Alistipes-putredinis-isolates/FC1.bam
    ## 排序和建立索引
    cd bt_mapped_Alistipes-putredinis-isolates
    samtools index FC1.bam
    cd ..

    ## 批量运行
    # 设置 Bowtie2 索引的前缀
    prefix="$species-isolates"
    # 包含 .fastq 文件的目录
    input_dir="../hr2"
    # BAM 文件的输出目录
    output_dir="bt_mapped_$species-isolates"
    # 确保输出目录存在
    mkdir -p $output_dir
    
    # 循环遍历输入目录中的所有 *_1.fastq 文件
    for fastq1 in "$input_dir"/*_1.fastq; do
      # 通过删除“_1.fastq”后缀获取样本名称
      sample_name=$(basename "$fastq1" _1.fastq)
      # 定义相应的_2.fastq文件
      fastq2="$input_dir/${sample_name}_2.fastq"
      # 定义输出 BAM 文件
      bam_output="${output_dir}/${sample_name}.bam"
      # 检查对应的_2.fastq文件是否存在
      if [[ -f "$fastq2" ]]; then
        # 运行 Bowtie2 和 SAMtools
        bowtie2 -x $prefix -1 $fastq1 -2 $fastq2 --no-unal --threads 24 | \
        samtools view -b - | \
        samtools sort -@ 12 - > $bam_output
        # 索引 BAM 文件
        samtools index $bam_output
      else
        # 如果不存在相应的 _2.fastq 文件，则警告
        echo "Warning: Missing corresponding _2.fastq file for $fastq1"
      fi
    done

    ## 使用 anvi’o 分析映射结果
    # 单样本运行
    anvi-profile -i bt_mapped_$species-isolates/FC1.bam -c $prefix-CONTIGS.db \
                  -W -M 2500 -T 12 --write-buffer-size 500 -o profs_mapped_$species-isolates/FC1/
    
    # 批量运行
    # 定义输入 BAM 目录
    bam_dir="bt_mapped_$species-isolates/"
    # 定义分析结果的输出目录
    output_dir="profs_mapped_$species-isolates"
    mkdir -p $output_dir
    # 循环遍历输入目录中的所有 BAM 文件
    for bam_file in $bam_dir/*.bam; do
      # 从 BAM 文件中提取样本名称（例如 FC1、FE1 等）
      sample_name=$(basename "$bam_file" .bam)
      # 为当前样本创建输出目录
      sample_output_dir="$output_dir/$sample_name"
      mkdir -p "$sample_output_dir"
      echo "Profiling sample $sample_name..."
      # 运行 anvi-profile 命令
      anvi-profile -i "$bam_file" -c "${prefix}-CONTIGS.db" -W -M 2500 -T 12 --write-buffer-size 500 -o "$sample_output_dir"
    done


## 6.3 pan-genome analysis (泛基因组分析)

    ## 生成合并的 anvi’o 配置文件数据库
    anvi-merge profs_mapped_$species-isolates/*/PROFILE.db \
               -o $species-isolates-MERGED \
               -c $species-isolates-CONTIGS.db
    ## 得到集合文件
    for split_name in `sqlite3 $species-isolates-CONTIGS.db 'select split from splits_basic_info;'`
    do
        GENOME=`echo $split_name | awk 'BEGIN{FS="-"}{print $1}'`
        echo -e "$split_name\t$GENOME"
    done > $species-GENOME-COLLECTION.txt
    
    anvi-import-collection $species-GENOME-COLLECTION.txt \
                           -c $species-isolates-CONTIGS.db \
                           -p $species-isolates-MERGED/PROFILE.db \
                           -C Genomes
                           
    anvi-summarize -c $species-isolates-CONTIGS.db \
                   -p $species-isolates-MERGED/PROFILE.db \
                   -C Genomes \
                   --init-gene-coverages \
                   -o $species-isolates-SUMMARY
               
    ## 生成internal-genomes-table.txt文件
    taxonPrefix=$species-isolates
    collection="Genomes"
    echo -e "name\tbin_id\tcollection_id\tprofile_db_path\tcontigs_db_path" > $taxonPrefix-internal-genomes-table.txt
    for bin in $(ls $taxonPrefix-SUMMARY/bin_by_bin); do
    echo -e "$bin\t$bin\t$collection\t$taxonPrefix-MERGED/PROFILE.db\t$taxonPrefix-CONTIGS.db" >> $taxonPrefix-internal-genomes-table.txt
    done

    ## 泛基因组计算
    anvi-gen-genomes-storage -i $species-isolates-internal-genomes-table.txt \
                             -o $species-PAN-GENOMES.db
    anvi-pan-genome -g $species-PAN-GENOMES.db \
                    --use-ncbi-blast \
                    --minbit 0.5 \
                    --mcl-inflation 10 \
                    --project-name $species-PAN \
                    --num-threads 24
    anvi-meta-pan-genome -i $species-isolates-internal-genomes-table.txt \
                    -g $species-PAN-GENOMES.db -p $species-PAN/*PAN.db

    ## 泛基因组绘图
    ## 此处的I为ip地址，例如这里是服务器的ip地址，需要根据自己实际情况修改；P为未被占用的端口，一般为8080或8082
    ## 直接在浏览器中打开结果给出的服务器网址，点击draw可得到相应的图，可在交互界面上得到基因组相关信息并对图进行调整
    anvi-display-pan -g $species-PAN-GENOMES.db \
                     -p $species-PAN/$species-PAN-PAN.db \
                     -I 192.168.60.214 \
    				 -P 8082
    
    # 每个样本中Alistipes putredinis的基因组信息                
    anvi-interactive -p $species-isolates-MERGED/PROFILE.db \
                     -c $species-isolates-CONTIGS.db \
                     -I 192.168.60.214 \
                     -P 8082
