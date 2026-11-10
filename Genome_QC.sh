#!/bin/bash
set -euo pipefail

# ============================================================
# GENOME QC PIPELINE (QUAST, BUSCO, Merqury, Teloscope)
#
# Uso:
#   ./Genome_QV.sh <assembly_hap1.fa> <assembly_hap2.fa> <reads.fastq.gz> <out_dir>
#
# Exemplo:
#   ./Genome_QV.sh \
#       3.hifiasm_l3/Cbr_hap1.fa \
#       4.qc_genoma
# ============================================================

# ============================================================
# CONFIGURAÇÕES
# ============================================================

BUSCO_lineage="/media/lgbio-nas1/lcorvalan/Pgu_genome/busco_downloads/lineages/eudicotyledons_odb12"
MERYL="/media/lgbio-nas1/lcorvalan/Pgu_genome/4.qc_genoma/Pgu_mgi_q15l5000.meryl"
THREADS=20

# ============================================================
# VERIFICAR ARGUMENTOS
# ============================================================

if [ "$#" -ne 2 ]; then
    echo
    echo "ERRO: número incorreto de argumentos."
    echo
    echo "Uso:"
    echo "  $0 <assembly_hap1.fa> <out_dir>"
    echo
    exit 1
fi

# ============================================================
# INPUTS
# ============================================================

FASTA_hap1=$(realpath "$1")
OUTDIR=$(realpath -m "$2")

for F in "$FASTA_hap1"; do
    if [ ! -f "$F" ]; then
        echo "ERRO: arquivo não encontrado: $F"
        exit 1
    fi
done

# ============================================================
# DIRETÓRIO DE SAÍDA
# ============================================================

mkdir -p "$OUTDIR"
cd "$OUTDIR"

# ============================================================
# AMBIENTE
# ============================================================

for CMD in quast.py merqury.sh; do
    command -v "$CMD" >/dev/null 2>&1 || { echo "ERRO: $CMD não encontrado."; exit 1; }
done



# ============================================================
# 1. QUAST
# ============================================================

echo "1. Rodando QUAST"

quast.py -t "$THREADS" -o Quast -s \
    --labels Primary \
    "$FASTA_hap1"

# ============================================================
# 2. BUSCO
# ============================================================

echo "2.1. Rodando BUSCO hap1"

source /usr/local/bin/miniconda/miniconda3/etc/profile.d/conda.sh
set +u
conda activate busco
set -u


export _JAVA_OPTIONS="-Xmx50G"

busco -i "$FASTA_hap1" \
    -l "$BUSCO_lineage" \
    -m genome \
    -o Busco_hap1 \
    -c "$THREADS" \
    -f --offline

#echo "2.2. Rodando BUSCO hap2"

#busco -i "$FASTA_hap2" \
#    -l "$BUSCO_lineage" \
#    -m genome \
#    -o Busco_hap2 \
#    -c "$THREADS" \
#    -f --offline

conda deactivate

# ============================================================
# 3. MERQURY
# ============================================================

echo "3. Rodando Merqury"

merqury.sh "$MERYL" "$FASTA_hap1" Merqury

# ============================================================
# 4. TELOSCOPE
# ============================================================

echo "4. Rodando Teloscope"

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate /media/lgbio-nas1/lcorvalan/conda_envs/teloscope

teloscope "$FASTA_hap1" \
    -c CCCTAAA \
    -p CCCTAAA,AAACCCT,TTTAGGG \
    -o Teloscope_hap1 \
    -w 25000 -s 25000 \
    -r --plot-report


# telomero Thamnophilidae -c TTAGGG -p TTAGGG,TCAGGG,TGAGGG,TTGGGG


conda deactivate

echo
echo "QC concluído. Resultados em: $OUTDIR"
