# Test FASTQ files

Place paired-end FASTQ files here, named as:

```
<SampleID>_1.fq.gz   # forward reads
<SampleID>_2.fq.gz   # reverse reads
```

Matching the `SampleID` column in `../result/metadata.txt`:

| Sample | Files expected |
|--------|----------------|
| Y1 | Y1_1.fq.gz  Y1_2.fq.gz |
| Y2 | Y2_1.fq.gz  Y2_2.fq.gz |
| C1 | C1_1.fq.gz  C1_2.fq.gz |
| C2 | C2_1.fq.gz  C2_2.fq.gz |

## Downloading public test data (SRA)

```bash
# Install sra-tools if needed
conda install -c bioconda sra-tools -y

# Example: download 4 samples (use real SRR accessions for your project)
# For a quick smoke-test you can use any small paired-end metagenome, e.g.:
prefetch SRR14092113 SRR14092114
fasterq-dump --split-files --outdir . SRR14092113
fasterq-dump --split-files --outdir . SRR14092114
pigz *.fastq

# Rename to match metadata SampleIDs:
mv SRR14092113_1.fastq.gz Y1_1.fq.gz
mv SRR14092113_2.fastq.gz Y1_2.fq.gz
mv SRR14092114_1.fastq.gz C1_1.fq.gz
mv SRR14092114_2.fastq.gz C1_2.fq.gz
```

## Generating synthetic reads (offline test without SRA)

```bash
# Requires: conda install -c bioconda art
# Generates 50 k paired 150 bp reads from a small reference genome
art_illumina -ss HS25 -i ref.fa -l 150 -c 50000 \
             -p -m 350 -s 20 -o Y1_ -na
gzip Y1_1.fq Y1_2.fq
```
