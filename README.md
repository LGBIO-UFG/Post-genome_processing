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

# 1. Purge

``` bash

cp /media/lgbio-nas1/lcorvalan/Cbr_genome/Cbr_2026/run_purge_dups.sh .

bash run_purge_dups_telo.sh \
    3.hifiasm_q20l10000_telo/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.fa \
    2.Filtragem-dadosbrutos/Cbr-08-07-2026_q20_l10000.fastq.gz

``` 
