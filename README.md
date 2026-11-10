# Post-genome_processing
Leonardo C. J. Corvalan
contact: lcjcorvalan@gmail.com
last update: 10-11-2026

This repository contains scripts for post-assembly genome processing.
1. Genome purge
2. Contaminant removal
3. Removal of non-nuclear genomes
4. Polishing (under development)
 
 * Additional script for automated quality metric evaluation.

## 0. Download scripts
```bash


```
## 1. Purge

``` bash

bash run_purge_dups_telo.sh \
    3.hifiasm_q20l10000_telo/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.fa \
    2.Filtragem-dadosbrutos/Cbr-08-07-2026_q20_l10000.fastq.gz

```

## 2. Removendo contanimants

### 2.1 Generating blobtool files and input

``` bash
# hap 1
bash run_blob.sh \
 3.hifiasm_q20l10000_telo/5.Purge_Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.purged.fa \
 2.Filtragem-dadosbrutos/Cbr-08-07-2026_q20_l10000.fastq.gz \
 3.hifiasm_q20l10000_tel/6.blobtools_hap1

```

### 2.2 ploting blobplot

``` bash

conda activate /media/lgbio-nas1/lcorvalan/conda_envs/blobtools_legacy

# you should acess this file to run

cd /home/lgbio/programas/blobtools

python blobtools plot -i /media/lgbio-nas1/lcorvalan/Cbr_genome/Cbr_2026/3.hifiasm_q20l10000_tel/6.blobtools_hap1/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.purged.blobtools.blobDB.json -r order --out /media/lgbio-nas1/lcorvalan/Cbr_genome/Cbr_2026/3.hifiasm_q20l10000_tel/6.blobtools_hap1/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.bloplot

```

### 2.3 Removing contigs

1. verify the contaminantion on blobplot .table.txt file

2. check the hits, GC and covarage
   eg.:
   h1tg000068l - Bacteroidota
   h1tg000079l - Ascomycota
   h1tg000088l - Ascomycota
   h1tg000089l - Ascomycota
   h1tg000093l - no-hit - low covarage
   h1tg000058l - Streptophyta/Saxifragales - low covarage
   h1tg000082l - hih covarage

3. Create a list with just the contig name one by line

``` bash
# create list
nano contaminations_hap1.txt

seqkit grep \
    -v \
    -f contaminations_hap1.txt\
    3.hifiasm_q20l10000_telo/5.Purge_Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.purged.fa \
    -o /media/lgbio-nas1/lcorvalan/Cbr_genome/Cbr_2026/3.hifiasm_q20l10000_telo/6.Blobtools_q20l10000_telo.hap1.nocontaminants.fa

```

# 3. Remove mitocondrial and plastidial genome

1. Dowloand the mitocondrial and cloroplatidial (plants) genome
   evaluate whether to generate the genomes or use those of closely related species
   
``` bash
# join cpDNA and mtDNA
cat Cbr_cpDNA.fasta Cbr_mtDNA1.fasta Cbr_mtDNA2.fasta > Cbr_organelles.fasta

# edit script
# check the number of threads and outdir

nano remove_organelle_contigs.sh

# OUTDIR="organelle_removal_telo_hap1"

# run
bash remove_organelle_contigs.sh /media/lgbio-nas1/lcorvalan/Cbr_genome/Cbr_2026/3.hifiasm_q20l10000_telo/6.Blobtools_q20l10000_telo.hap1.nocontaminants.fa Cbr_organelles.fasta 40

```

## 4. Run the genome quality inspection
This will run:
1.Quast
2.Busco
3.Merquery
4.Teloscope

ther meryl libary and busco db shoulb create/download previusly

``` bash

bash Genome_QC.sh \
       organelle_removal_telo_hap2/genome_without_organelles.fasta \
       Genome_QC

```
