# Post-Genome Processing

**Author:** Leonardo C. J. Corvalan
**Contact:** lcjcorvalan@gmail.com
**Last updated:** 2026-11-10

This repository contains a set of scripts for processing a genome assembly after it has been generated (post-assembly). The workflow takes a draft assembly (for example, produced with hifiasm from HiFi reads and Hi-C data) and turns it into a cleaner, decontaminated, nuclear-only assembly that is ready for quality assessment and downstream analyses.

## Table of Contents

- [Pipeline overview](#pipeline-overview)
- [Requirements](#requirements)
- [Step 0 - Download the scripts](#step-0---download-the-scripts)
- [Step 1 - Purge duplicates](#step-1---purge-duplicates)
- [Step 2 - Remove contaminants](#step-2---remove-contaminants)
- [Step 3 - Remove mitochondrial and plastid contigs](#step-3---remove-mitochondrial-and-plastid-contigs)
- [Step 4 - Genome quality inspection](#step-4---genome-quality-inspection)
- [Additional tools](#additional-tools)
- [Notes and troubleshooting](#notes-and-troubleshooting)

---

## Pipeline overview

```
Draft assembly (hifiasm, hap1)
        │
        ▼
1. Purge duplicates  ─────────►  purged assembly
        │
        ▼
2. Contaminant removal ───────►  BlobTools plot + list of contaminant contigs
        │                        → assembly without contaminants
        ▼
3. Organelle removal ─────────►  assembly without mitochondrial/plastid contigs
        │
        ▼
4. Quality control (QUAST, BUSCO, Merqury, Teloscope)
```

| Step | Goal | Main tools |
|------|------|------------|
| 0 | Get the scripts | git |
| 1 | Remove haplotig/duplicated contigs and trim telomere-related sequences | `run_purge_dups_telo.sh` (purge_dups) |
| 2 | Identify and remove non-target (bacterial, fungal, plant-other) contigs | `run_blob.sh`, BlobTools, seqkit |
| 3 | Remove mitochondrial and plastid (chloroplast) contigs | `remove_organelle_contigs.sh` |
| 4 | Assess assembly completeness, correctness and contiguity | `Genome_QC.sh` (QUAST, BUSCO, Merqury, Teloscope) |

---

## Requirements

Before running the pipeline, make sure you have:

- **Conda** (to create or activate the environments used by some tools)
- **BlobTools** (legacy version, installed in a dedicated conda environment)
- **seqkit** (used to filter contigs out of the FASTA file)
- **purge_dups**, **minimap2** and **BWA/minimap2 read mapping tools** (used by the purge step)
- **QUAST**, **BUSCO** (with the lineage dataset downloaded in advance), **Merqury** with a pre-built **meryl** k-mer library, and **Teloscope**
- **Input data**:
  - Draft assembly in FASTA format (e.g., `*.hic.hap1.p_ctg.fa`)
  - Filtered HiFi reads in FASTQ format (`*.fastq.gz`)
  - Organelle reference sequences (chloroplast and mitochondrial) in FASTA format

> **Important:** The meryl library and the BUSCO database must be created or downloaded **before** running Step 4.

---

## Step 0 - Download the scripts

```bash
git clone <REPOSITORY_URL>
cd Post-genome_processing
```

Make the scripts executable (optional, since they are run with `bash`):

```bash
chmod +x *.sh
```

---

## Step 1 - Purge duplicates

This step removes duplicated haplotigs (contigs that represent the same genomic region assembled twice) and handles telomeric regions, using `purge_dups` guided by the HiFi reads.

**Input**
- `*.hic.hap1.p_ctg.fa`: draft haplotype 1 assembly (output of hifiasm)
- `*_q20_l10000.fastq.gz`: filtered HiFi reads (Q20, minimum length 10 kb)

**Command**

```bash
bash run_purge_dups_telo.sh \
    3.hifiasm_q20l10000_telo/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.fa \
    2.Filtragem-dadosbrutos/Cbr-08-07-2026_q20_l10000.fastq.gz
```

**Output**
- A purged assembly inside the folder `5.Purge_<assembly_name>/`, named `<assembly_name>.purged.fa`. This is the file used in Step 2.

---

## Step 2 - Remove contaminants

Contaminant removal is done in three sub-steps: generating BlobTools files, plotting the blob plot to inspect the contigs, and removing the selected contigs.

### 2.1 Generate the BlobTools input files

This step aligns the reads back to the purged assembly and runs the BLAST/coverage analysis needed by BlobTools.

```bash
# Haplotype 1
bash run_blob.sh \
    3.hifiasm_q20l10000_telo/5.Purge_Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.purged.fa \
    2.Filtragem-dadosbrutos/Cbr-08-07-2026_q20_l10000.fastq.gz \
    3.hifiasm_q20l10000_telo/6.blobtools_hap1
```

**Output:** the BlobTools `blobDB.json` file and the `.table.txt` summary inside `6.blobtools_hap1/`.

### 2.2 Plot the blob plot

Activate the BlobTools environment and run the plot. The BlobTools script must be run from its installation directory.

```bash
conda activate /media/lgbio-nas1/lcorvalan/conda_envs/blobtools_legacy

cd /home/lgbio/programas/blobtools

python blobtools plot \
    -i /media/lgbio-nas1/lcorvalan/Cbr_genome/Cbr_2026/3.hifiasm_q20l10000_telo/6.blobtools_hap1/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.purged.blobtools.blobDB.json \
    -r order \
    --out /media/lgbio-nas1/lcorvalan/Cbr_genome/Cbr_2026/3.hifiasm_q20l10000_telo/6.blobtools_hap1/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.blobplot
```

**Output:** blob plot images (GC content vs. coverage, coloured by taxonomic order).

### 2.3 Identify and remove contaminant contigs

1. **Check the taxonomy** in the `.table.txt` file generated by BlobTools.
2. **Inspect each suspicious contig** by looking at its hit (taxonomy), GC content and coverage. Example of what to look for:

   | Contig | Hit (taxonomy) | Comment |
   |--------|----------------|---------|
   | h1tg000068l | Bacteroidota | Bacterial contamination |
   | h1tg000079l | Ascomycota | Fungal contamination |
   | h1tg000088l | Ascomycota | Fungal contamination |
   | h1tg000089l | Ascomycota | Fungal contamination |
   | h1tg000093l | no-hit | Low coverage |
   | h1tg000058l | Streptophyta/Saxifragales | Low coverage |
   | h1tg000082l | - | High coverage (check carefully before removing) |

   > Contigs with **no hit** and **high coverage** may be real genomic sequence (e.g., repeats or unplaced haplotype). Do not remove them without further evidence.

3. **Create a text file** with one contig name per line:

   ```bash
   nano contaminations_hap1.txt
   ```

   ```text
   h1tg000068l
   h1tg000079l
   h1tg000088l
   h1tg000089l
   h1tg000093l
   h1tg000058l
   ```

4. **Remove the listed contigs** with `seqkit grep` (`-v` means *invert match*, i.e. keep everything *except* the listed contigs):

   ```bash
   seqkit grep \
       -v \
       -f contaminations_hap1.txt \
       3.hifiasm_q20l10000_telo/5.Purge_Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg/Cbr-08-07-2026_q20l10000_l3_telo.hic.hap1.p_ctg.purged.fa \
       -o /media/lgbio-nas1/lcorvalan/Cbr_genome/Cbr_2026/3.hifiasm_q20l10000_telo/6.Blobtools_q20l10000_telo.hap1.nocontaminants.fa
   ```

**Output:** `6.Blobtools_q20l10000_telo.hap1.nocontaminants.fa`

---

## Step 3 - Remove mitochondrial and plastid contigs

Organelle genomes (mitochondrial and, for plants, plastid/chloroplast) are often assembled together with the nuclear genome. This step removes them so that the final assembly contains only nuclear sequences.

### 3.1 Obtain the organelle references

Download the mitochondrial and chloroplast genomes of the target species. If they are not available, use those of a closely related species. Then combine them into a single FASTA file:

```bash
cat Cbr_cpDNA.fasta Cbr_mtDNA1.fasta Cbr_mtDNA2.fasta > Cbr_organelles.fasta
```

### 3.2 Configure and run the script

Open the script and check the number of threads and the output directory before running:

```bash
nano remove_organelle_contigs.sh
# Example: OUTDIR="organelle_removal_telo_hap1"
```

```bash
bash remove_organelle_contigs.sh \
    /media/lgbio-nas1/lcorvalan/Cbr_genome/Cbr_2026/3.hifiasm_q20l10000_telo/6.Blobtools_q20l10000_telo.hap1.nocontaminants.fa \
    Cbr_organelles.fasta \
    40
```

**Arguments**

| Position | Argument | Description |
|----------|----------|-------------|
| 1 | Assembly FASTA | Assembly without contaminants (output of Step 2) |
| 2 | Organelle FASTA | Combined chloroplast and mitochondrial sequences |
| 3 | Threads | Number of CPU threads (here: 40) |

**Output:** `genome_without_organelles.fasta` inside the output directory (`organelle_removal_telo_hap1/`).

---

## Step 4 - Genome quality inspection

`Genome_QC.sh` runs a full set of quality metrics on the final assembly:

| Tool | What it evaluates |
|------|-------------------|
| **QUAST** | Contiguity statistics (N50, number of contigs, total length, etc.) |
| **BUSCO** | Completeness based on universal single-copy orthologs |
| **Merqury** | Assembly consensus quality and k-mer completeness (uses a pre-built meryl library) |
| **Teloscope** | Detection of telomeric repeats at contig ends |

**Before running:** create the meryl k-mer database and download the BUSCO lineage dataset.

```bash
bash Genome_QC.sh \
    organelle_removal_telo_hap1/genome_without_organelles.fasta \
    Genome_QC
```

**Arguments**

| Position | Argument | Description |
|----------|----------|-------------|
| 1 | Final assembly FASTA | Output of Step 3 |
| 2 | Output directory | Folder where all QC results will be written (`Genome_QC/`) |

---

## Additional tools

- **Automated quality metric evaluation:** an additional script is provided to summarise the QC metrics produced in Step 4.
- **Polishing:** under development. This step will be added in a future update.

---

## Notes and troubleshooting

- **Use absolute paths** for the BlobTools steps when running from a different directory, as shown in the examples.
- **Check haplotype naming.** Keep the haplotype identifier (`hap1`, `hap2`) consistent across all steps and output folders to avoid mixing files.
- **Check the number of threads** in `remove_organelle_contigs.sh` and `Genome_QC.sh` to match your machine.
- **Verify every removal.** Always inspect contaminant and organelle contigs before deleting them. Removing real nuclear sequence is harder to recover from than leaving a small contaminant.
- **Run the blob plot step from the BlobTools installation directory** if the script depends on relative paths.

---

## Citation and contact

If you use these scripts in your work, please cite the tools they depend on (hifiasm, purge_dups, BlobTools, seqkit, QUAST, BUSCO, Merqury and Teloscope).

**Questions or suggestions?** Contact Leonardo C. J. Corvalan at lcjcorvalan@gmail.com.
