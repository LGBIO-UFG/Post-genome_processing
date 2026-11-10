#!/bin/bash
set -euo pipefail

# ============================================================
# bloplot PIPELINE
#
# Uso:
#   ./run_blob.sh <assembly.fa> <reads.fastq.gz> <out_dir>
#
# Exemplo:
#   ./run_blob.sh \
#       3.hifiasm_l3/Cbr-08-07-2026_q15l5000_l3.hic.hap2.p_ctg.fa \
#       2.Filtragem-dadosbrutos/Cbr-08-07-2026_q15_l5000.fastq.gz \
#       bloplot_Hap1
# ============================================================

# ============================================================
# CONFIGURAÇÕES
# ============================================================

NCBIDB="/media/hd16-databases/blast_dbs/core_nt/core_nt"
THREADS_MAP=20
THREADS_BLAST=20

# ============================================================
# VERIFICAR ARGUMENTOS
# ============================================================

if [ "$#" -ne 3 ]; then
    echo
    echo "ERRO: número incorreto de argumentos."
    echo
    echo "Uso:"
    echo "  $0 <assembly.fa> <reads.fastq.gz> <out_dir>"
    echo
    echo "Exemplo:"
    echo "  $0 assembly.fa reads.fastq.gz <out_dir>"
    echo
    exit 1
fi

# ============================================================
# DIRETÓRIO DE SAÍDA (criar antes do realpath)
# ============================================================
mkdir -p "$3"
OUTDIR=$(realpath "$3")

# ============================================================
# INPUTS
# ============================================================
FASTA=$(realpath "$1")
READS=$(realpath "$2")


if [ ! -f "$FASTA" ]; then
    echo "ERRO: FASTA não encontrado:"
    echo "$FASTA"
    exit 1
fi

if [ ! -f "$READS" ]; then
    echo "ERRO: FASTQ não encontrado:"
    echo "$READS"
    exit 1
fi

# ============================================================
# NOMES
# ============================================================

BASENAME=$(basename "$FASTA")
PREFIX="${BASENAME%.*}"


# ============================================================
# 1. ALINHAMENTO
# ============================================================

minimap2 -ax map-ont -t "$THREADS_MAP" "$FASTA" "$READS" \
    | samtools sort -o "$OUTDIR/$PREFIX.bam" -

samtools index "$OUTDIR/$PREFIX.bam"

# ============================================================
# 2. BLAST contra nt
# ============================================================

blastn -query "$FASTA" \
    -db "$NCBIDB" \
    -outfmt "6 qseqid staxids bitscore std" \
    -max_target_seqs 10 \
    -max_hsps 1 \
    -evalue 1e-25 \
    -num_threads "$THREADS_BLAST" \
    -out "$OUTDIR/$PREFIX.blastn.out"

# ============================================================
# 3. BLOBTOOLS
# ============================================================

# conda activate pode falhar com set -u, então é desativado temporariamente
set +u
source /usr/local/bin/miniconda/miniconda3/etc/profile.d/conda.sh
conda activate blobtools
set -u

# Criar blobdb
blobtools create \
    -i "$FASTA" \
    -b "$OUTDIR/$PREFIX.bam" \
    -t "$OUTDIR/$PREFIX.blastn.out" \
    -o "$OUTDIR/$PREFIX.blobtools"

# Gerar tabela
blobtools view \
    -i "$OUTDIR/$PREFIX.blobtools.blobDB.json" \
    -r all \
    --out "$OUTDIR/$PREFIX.blobtools.tsv"

echo "Pipeline concluído. Saídas em: $OUTDIR"
