[TOC]

# 08 Appendix: Troubleshooting and Supplementary Code (08附录：常见问题和补充代码)

    # Source: extracted from 1Pipeline.sh Appendix
    # Authors(作者): Yong-Xin Liu(刘永鑫), Defeng Bai(白德凤), Tong Chen(陈同) et al.
    # Version(版本): 1.24, 2025/11/22
## Calculation Time Statistics Table (计算时间统计表)

    # 在60核(p)及以上服务器，单样本3个并行推荐16p，混合组装分箱推荐32p。
    # 小数据：2个7.5M样本，在72个核、512GB服务器上测试。
    # 大数据：20个10G样本，在192个核、2TB大内存服务器上测试。
    # | 步骤 | 数据小(6Gx3) | 数据(10Gx20) | 备注 |
    # | --- | --- | --- | --- |
    # | fastqc | 33s | 15m |  |
    # | seqkit | 2s | 15m |  |
    # | fastp | 2s | 40m |  |
    # | kneaddata | 25s | 5h |  |
    # | humann | 34m | 30h |  |
    # | megahit | 39s | 15h |  |
    # | binning | 6h | 16h | -concoct |
    # | binrefine | 2h | 3h |  |
    # | coverm | 4m | 30m |  |
    # 注：m为分，h为小时，d为天


## Supplementary scripts (补充代码)

    #**for循环批量处理样本列表**
    # 基于样本元数据提取样本列表命令解析
    # 去掉表头
    tail -n+2 result/metadata.txt
    # 提取第一列样本名
    tail -n+2 result/metadata.txt|cut -f1
    # 循环处理样本
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do echo "Processing "$i; done
    # ` 反引号为键盘左上角Esc键下面的按键，一般在数字1的左边，代表运行命令返回结果
    

## KneadData质控去宿主

    # **双端序列质控后是否配对的检查**
    # 双端序列质控后序列数量不一致是肯定出错了。但即使序列数量一致，也可能序列不对。在运行metawrap分箱时会报错。可以kneaddata运行时添加--reorder来尝试解决。以下提供了检查双端序列ID是否配对的比较代码
    # 文件
    i=C1
    seqkit seq -n -i temp/qc/${i}_1_kneaddata_paired_1.fastq|cut -f 1 -d '/' | head > temp/header_${i}_1
    seqkit seq -n -i temp/qc/${i}_1_kneaddata_paired_2.fastq|cut -f 1 -d '/' | head > temp/header_${i}_2
    cmp temp/header_${i}_?

    # 如果序列双端名称一致，且单样本质控结果异常时使用，适合旧版本：新版全kneaddata 1.12已经将此功能添加至流程，以下代码运行返倒引起错误
    #序列改名，解决NCBI SRA数据双端ID重名问题，详见[《MPB：随机宏基因组测序数据质量控制和去宿主的分析流程和常见问题》](https://mp.weixin.qq.com/s/ovL4TwalqZvwx5qWb5fsYA)。
    # 以0.12.0为例，序列中间不一至存在:1和:2会无结果，
    @A01909:80:HFT7YDSX5:2:1101:1289:1000 1:N:0:ATGAATAT+TTAAGTGG
    @A01909:80:HFT7YDSX5:2:1101:1289:1000 2:N:0:ATGAATAT+TTAAGTGG
    # 以0.12.0为例，最终的结果为无空格，结果/1和/2
    @A01909:80:HFT7YDSX5:2:1101:1289:1000.1:N:0:ATGAATAT+TTAAGTGG/1
    @A01909:80:HFT7YDSX5:2:1101:1289:1000.1:N:0:ATGAATAT+TTAAGTGG/2
    # 以单个样本修改
    i=A01
    sed -i '1~4 s/ 1:/.1:/;1~4 s/$/\/1/' temp/qc/${i}_1.fastq
    sed -i '1~4 s/ 2:/.1:/;1~4 s/$/\/2/' temp/qc/${i}_2.fastq
    # 批量修改
    sed -i '1~4 s/ 1:/.1:/;1~4 s/$/\/1/' temp/qc/${i}_1.fastq
    sed -i '1~4 s/ 1:/.1:/;1~4 s/$/\/1/' temp/qc/${i}_2.fastq

    # **Perl环境不匹配**
    # 报错'perl binaries are mismatched'的解决
    e=~/miniconda3/envs/meta
    PERL5LIB=${e}/lib/5.26.2:${e}/lib/5.26.2/x86_64-linux-thread-multi

    ## **Java环境错误**
    # 出现错误 Unrecognized option: -d64，为版本不匹配——重装Java运行环境解决：
    conda install -c cyclus java-jdk
    # 若出现错误 Error message returned from Trimmomatic :
    # Error: Invalid or corrupt jarfile \~/miniconda3/envs/kneaddata/share/trimmomatic/trimmomatic；找不到程序，修改配置文件指定脚本名称
    sed -i 's/trimmomatic\*/trimmomatic.jar/' ~/miniconda3/envs/kneaddata/lib/python3.10/site-packages/kneaddata/config.py


    # **Python环境不匹配-找不到包module**
    # ModuleNotFoundError: No module named 'importlib.metadata'
    # 找不到包，一般是环境变量错误，先确定是否正常启动conda环境，没有重复启动 conda activate kneaddata。已启动检测环境变量
    echo $PATH
    # /public/software/env01/bin:/public/home/liuyongxin/miniconda3/envs/kneaddata/bin:/public/home/liuyongxin/miniconda3/condabin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin
    # 确认conda环境是否为第一个路径，此处kneaddata路径前还有更高优先级的目录在前，重设PATH变量，即删除当前conda环境前的所有路径
    PATH=/public/home/liuyongxin/miniconda3/envs/kneaddata/bin:/public/home/liuyongxin/miniconda3/condabin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin

## HUMANN物种功能定量

    # **metaphlan_to_stamp.pl**
    # 如果出现下面的错误：
    # bash: /db/EasyMicrobiome/script/metaphlan_to_stamp.pl: /usr/bin/perl^M: 解释器错误: 没有那个文件或目录
    # sed -i 's/\r//' ${db}/EasyMicrobiome/script/*.pl  


    # **HUMAnN2减少输入文件加速**
    # HUMAnN2是计算非常耗时的步骤，如果上百个10G+的样本，有时需要几周至几月的分析。以下介绍两种快速完成分析，而且结果变化不大的方法。替换下面for循环为原文中的“双端合并为单个文件”部分代码
    # 方法1. 软件分析不考虑双端信息，只用一端可获得相近结果，且速度提高1倍。链接质控结果左端高质量至合并目录
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do 
      ln -sf `pwd`/temp/hr/${i}_1.fastq temp/concat/${i}.fq
    done

    # 方法2. 控制标准样比对时间。测序数据量通常为6~50G，同一样本分析时间可达10h~100h，严重浪费时间而浪费硬盘空间。
    # 可用head对单端分析截取20M序列，即3G，则为80M行
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do 
       head -n80000000 temp/qc/${i}_1_kneaddata_paired_1.fastq  > temp/concat/${i}.fq
    done

    # **metaphlan2-共有或特有物种网络图**
    awk 'BEGIN{OFS=FS="\t"}{if(FNR==1) {for(i=9;i<=NF;i++) a[i]=$i; print "Tax\tGroup"} \
       else {for(i=9;i<=NF;i++) if($i>0.05) print "Tax_"FNR, a[i];}}' \
       result/metaphlan2/taxonomy.spf > result/metaphlan2/taxonomy_highabundance.tsv
    awk 'BEGIN{OFS=FS="\t"}{if(FNR==1) {print "Tax\tGrpcombine";} else a[$1]=a[$1]==""?$2:a[$1]$2;}END{for(i in a) print i,a[i]}' \
       result/metaphlan2/taxonomy_highabundance.tsv > result/metaphlan2/taxonomy_group.tsv
    cut -f 2 result/metaphlan2/taxonomy_group.tsv | tail -n +2 | sort -u >group
    for i in `cat group`; do printf "#%02x%02x%02x\n" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)); done >colorcode
    paste group colorcode >group_colorcode
    awk 'BEGIN{OFS=FS="\t"}ARGIND==1{a[$1]=$2;}ARGIND==2{if(FNR==1) {print $0, "Grpcombinecolor"} else print $0,a[$2]}' \
       group_colorcode result/metaphlan2/taxonomy_group.tsv > result/metaphlan2/taxonomy_group2.tsv
    awk 'BEGIN{OFS=FS="\t"}{if(FNR==1) {print "Tax",$1,$2,$3,$4, $5, $6, $7, $8 } else print "Tax_"FNR, $1,$2,$3,$4, $5,$6, $7, $8}' \
       result/metaphlan2/taxonomy.spf > result/metaphlan2/taxonomy_anno.tsv

## LEfSe生物标志鉴定

    # **lefse-plot_cladogram.py：Unknown property axis_bgcolor**
    # 若出现错误 Unknown property axis\_bgcolor，则修改`lefse-plot_cladogram.py`里的`ax_bgcolor`替换成`facecolor`即可。
    # 查看脚本位置，然后使用RStudio或Vim修改
    type lefse-plot_cladogram.py

## Kraken2物种分类

    # **合并样本为表格combine_mpa.py**
    # krakentools中combine_mpa.py，需手动安装脚本，且结果还需调整样本名
    combine_mpa.py \
      -i `tail -n+2 result/metadata.txt|cut -f1|sed 's/^/temp\/kraken2\//;s/$/.mpa/'|tr '\n' ' '` \
      -o temp/kraken2/combined_mpa

    # **序列筛选/去宿主extract_kraken_reads.py**
    # 提取非植物33090和动物(人)33208序列、选择细菌2和古菌2157
    mkdir -p temp/kraken2_qc
    parallel -j 3 \
      "/db/script/extract_kraken_reads.py \
      -k temp/kraken2/{1}.output \
      -r temp/kraken2/{1}.report \
      -1 temp/qc/{1}_1_kneaddata_paired_1.fastq \
      -2 temp/qc/{1}_1_kneaddata_paired_2.fastq \
      -t 33090 33208 --include-children --exclude \
      --max 20000000 --fastq-output \
      -o temp/kraken2_qc/{1}_1.fq \
      -o2 temp/kraken2_qc/{1}_2.fq" \
      ::: `tail -n+2 result/metadata.txt|cut -f1`

## 2nd+3rd assemble (二三代混合组装)

    # **metaspades**
    # 3G数据，耗时3h
    i=SampleA
    time metaspades.py -t 48 -m 500 \
      -1 seq/${i}_1.fastq -2 seq/${i}L_2.fastq \
      --nanopore seq/${i}.fastq \
      -o temp/metaspades_${i}

    # **二三代混合组装OPERA-MS**
    # 结果卡在第9步polishing，可添加--no-polishing参数跳过此步；短序列只支持成对文件，多个文件需要cat合并
    perl ../OPERA-MS.pl \
        --short-read1 R1.fastq.gz \
        --short-read2 R2.fastq.gz \
        --long-read long_read.fastq \
        --no-ref-clustering \
        --num-processors 32 \
        --out-dir RESULTS

    # **二代组装+三代优化**
    perl ~/soft/OPERA-MS/OPERA-MS.pl \
        --contig-file temp/megahit/final.contigs.fa \
        --short-read1 R1.fastq.gz \
        --short-read2 R2.fastq.gz \
        --long-read long_read.fastq \
        --num-processors 32 \
        --no-ref-clustering \
        --no-strain-clustering \
        --no-polishing \
        --out-dir temp/opera

## prodigal gene prediction (基因预测)

    # **序列拆分并行预测基因**
    # (可选)以上注释大约1小时完成1M个基因的预测。加速可将contigs拆分，并行基因预测后再合并。
    # 拆分contigs，按1M条每个文件
    n=10000
    seqkit split result/megahit/final.contigs.fa -s $n
    # 生成拆分文件序列列表
    ls result/megahit/final.contigs.fa.split/final.contigs.part_*.fa|cut -f 2 -d '_'|cut -f 1 -d '.' \
      > temp/split.list
    # 9线程并行基因预测，此步只用单线程且读写强度不大
    time parallel -j 9 \
      "prodigal -i result/megahit/final.contigs.fa.split/final.contigs.part_{}.fa \
      -d temp/gene{}.fa  \
      -o temp/gene{}.gff -p meta -f gff \
      > temp/gene{}.log 2>&1 " \
      ::: `cat temp/split.list`
    # 合并预测基因和gff注释文件
    cat temp/gene*.fa > temp/prodigal/gene.fa
    cat temp/gene*.gff > temp/prodigal/gene.gff

## cd-hit gene redundancy (基因去冗余)

    # **两批基因合并cd-hit-est-2d**
    # cd-hit-est-2d 两批次构建非冗余基因集
    # A和B基因集，分别有M和N个非冗余基因，两批数据合并后用cd-hit-est去冗余，计算量是(M + N) X (M + N -1)
    # cd-hit-est-2d比较，只有M X N的计算量

    # 计算B中特有的基因
    cd-hit-est-2d -i A.fa -i2 B.fa -o B.uni.fa \
        -aS 0.9 -c 0.95 -G 0 -g 0 \
        -T 96 -M 0 -d 0
    # 合并为非冗余基因集
    cat A.fa B.uni.fa > NR.fa

    # **cd-hit合并多批基因salmon索引时提示ID重复**
    # [error] In FixFasta, two references with the same name but different sequences: k141_2390219_1. We require that all input records have a unique name up to the first whitespace (or user-provided separator) character.
    # 错误解决
    mv temp/NRgene/gene.fa temp/NRgene/gene.fa.bak
    # 15G,2m,4G
    seqkit rename temp/NRgene/gene.fa.bak -o temp/NRgene/gene.fa

## salmon gene quantify (基因定量)

    # **找不到库文件liblzma.so.0**
    # 
    # *   报错信息：error while loading shared libraries: liblzma.so.0
    # *   问题描述：直接运行salmon报告，显示找不到lib库，
    # *   解决方法：可使用程序完整路径解决问题，`alias salmon="${soft}/envs/metagenome_env/share/salmon/bin/salmon"`

## Gene annotation database (基因功能数据库)

    # **综合功能注释KEGG描述整理**
    # 脚本位于 /db/script 目录，<https://www.kegg.jp/kegg-bin/show_brite?ko00001.keg> 下载htext，即为最新输入文件 ko00001.keg
    kegg_ko00001_htext2tsv.pl -i ko00001.keg -o ko00001.tsv
    # 原核蛋白数据库(需付费购买)建索引
    conda activate eggnog
    diamond --version # 2.0.13
    cd genes/fasta
    # 3m, 2G
    memusg -t diamond makedb --in prokaryotes.pep.gz \
      --db prokaryotes.pep
    
    # ID转换为KO
    zless prokaryotes.dat.gz|cut -f1,2|sed "1i Kgene\tKO">prokaryotes.gene2KO

    # **抗生素抗性ResFam**
    # 数据库：<http://www.dantaslab.org/resfams>
    # 参考文献：<http://doi.org/10.1038/ismej.2014.106>
    mkdir -p temp/resfam result/resfam
    # 比对至抗生素数据库 1m
    time diamond blastp \
      --db ${db}/resfam/Resfams-proteins \
      --query result/NR/protein.fa \
      --threads 9 --outfmt 6 --sensitive \
      -e 1e-5 --max-target-seqs 1 --quiet \
      --out temp/resfam/gene_diamond.f6
    # 提取基因对应抗性基因列表
    cut -f 1,2 temp/resfam/gene_diamond.f6 | uniq | \
      sed '1 i Name\tResGeneID' > temp/resfam/gene_fam.list
    # 统计注释基因的比例, 488/19182=2.5%
    wc -l temp/resfam/gene_fam.list  result/salmon/gene.count 
    # 按列表累计丰度
    summarizeAbundance.py \
      -i result/salmon/gene.TPM \
      -m temp/resfam/gene_fam.list \
      -c 2 -s ',' -n raw \
      -o result/resfam/TPM
    # 结果中添加FAM注释，spf格式用于stamp分析
    awk 'BEGIN{FS=OFS="\t"} NR==FNR{a[$1]=$4"\t"$3"\t"$2} NR>FNR{print a[$1],$0}' \
      ${db}/resfam/Resfams-proteins_class.tsv  result/resfam/TPM.ResGeneID.raw.txt \
      > result/resfam/TPM.ResGeneID.raw.spf

## MetaWRAP binning (分箱)

    # **MetaWRAP分箱注释Bin classify & annotate**
    # Taxator-tk对每条contig物种注释，再估计bin整体的物种，11m (用时66 min)
    metawrap classify_bins -b temp/bin_refinement/metawrap_50_10_bins \
      -o temp/bin_classify -t 3 &
    # 注释结果见`temp/bin_classify/bin_taxonomy.tab`

    # export LD_LIBRARY_PATH=/conda2/envs/metagenome_env/lib/:${LD_LIBRARY_PATH}
     # 这是动态链接库找不到时的一个简单的应急策略
    #ln -s /conda2/envs/metagenome_env/lib/libssl.so.1.0.0 .
    #ln -s /conda2/envs/metagenome_env/lib/libcrypto.so.1.0.0 .

    # 基于prokka基因注释，4m
    metaWRAP annotate_bins -o temp/bin_annotate \
      -b temp/bin_refinement/metawrap_50_10_bins  -t 5
    # 每个bin基因注释的gff文件bin_funct_annotations, 
    # 核酸ffn文件bin_untranslated_genes，
    # 蛋白faa文件bin_translated_genes
    ls -sh temp/bin_annotate/prokka_out/bin.1/

    # **分箱定量Bin quantify**
    # 耗时3m，系统用时10m，此处可设置线程，但salmon仍调用全部资源
    metawrap quant_bins -b temp/bin_refinement/metawrap_50_10_bins -t 4 \
      -o temp/bin_quant -a temp/megahit/final.contigs.fa temp/qc/ERR*.fastq
    # 文件名字改变
    # 结果包括bin丰度热图`temp/bin_quant/bin_abundance_heatmap.png`
    # 原始数据位于`temp/bin_quant/bin_abundance_table.tab`
    ls -l temp/bin_quant/bin_abundance_heatmap.png

    # **GTDB的文件名不存在错**
    # ERROR: ['BMN5'] are not present in the input list of genome to process，但并无此菌，可能是名称 中存在"-"或"."，替换为i
    # 修改metadata
    sed 's/-/i/;s/\./i/' result/metadatab.txt > result/metadata.txt
