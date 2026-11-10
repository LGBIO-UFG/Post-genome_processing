#!/bin/bash

set -euo pipefail

# ============================================================
# PURGE_DUPS PIPELINE
#
# Uso:
#   ./run_purge_dups.sh <assembly.fa> <reads.fastq.gz>
#
# Exemplo:
#   ./run_purge_dups.sh \
#       3.hifiasm_l3/Cbr-08-07-2026_q15l5000_l3.hic.hap2.p_ctg.fa \
#       2.Filtragem-dadosbrutos/Cbr-08-07-2026_q15_l5000.fastq.gz
#
# ============================================================


# ============================================================
# CONFIGURAÇÕES
# ============================================================

PURGE="/home/lgbio/programas/purge_dups/bin"
PURGE_SCRIPTS="/home/lgbio/programas/purge_dups/scripts"

THREADS_MAP=20
THREADS_SELF=20


# ============================================================
# VERIFICAR ARGUMENTOS
# ============================================================

if [ "$#" -ne 2 ]; then

    echo
    echo "ERRO: número incorreto de argumentos."
    echo
    echo "Uso:"
    echo "  $0 <assembly.fa> <reads.fastq.gz>"
    echo
    echo "Exemplo:"
    echo "  $0 assembly.fa reads.fastq.gz"
    echo

    exit 1
fi


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
# DIRETÓRIO DE SAÍDA
# ============================================================

FASTA_DIR=$(dirname "$FASTA")

OUTDIR="${FASTA_DIR}/5.Purge_${PREFIX}"

mkdir -p "$OUTDIR"


# ============================================================
# ARQUIVOS
# ============================================================

ALIGNMENT="${OUTDIR}/${PREFIX}.paf.gz"

SPLIT_FA="${OUTDIR}/${PREFIX}.split.fa"

SELF_PAF="${OUTDIR}/${PREFIX}.self.paf.gz"

DUPS_BED="${OUTDIR}/${PREFIX}.dups.bed"

PURGE_LOG="${OUTDIR}/${PREFIX}.purge_dups.log"

CALCUTS_LOG="${OUTDIR}/${PREFIX}.calcuts.log"

HIST_PLOT="${OUTDIR}/${PREFIX}.PB.cov.png"

PURGED_FA="${OUTDIR}/${PREFIX}.purged.fa"


# ============================================================
# INFORMAÇÕES
# ============================================================

echo
echo "============================================================"
echo "                    PURGE_DUPS PIPELINE"
echo "============================================================"
echo
echo "Assembly:"
echo "  $FASTA"
echo
echo "Reads:"
echo "  $READS"
echo
echo "Output:"
echo "  $OUTDIR"
echo
echo "Threads minimap2:"
echo "  $THREADS_MAP"
echo
echo "Threads self-alignment:"
echo "  $THREADS_SELF"
echo
echo "============================================================"
echo


# ============================================================
# VERIFICAR PROGRAMAS
# ============================================================

if ! command -v minimap2 >/dev/null 2>&1; then

    echo "ERRO: minimap2 não encontrado no PATH."

    exit 1
fi


for PROGRAM in split_fa pbcstat calcuts purge_dups get_seqs
do

    if [ ! -x "${PURGE}/${PROGRAM}" ]; then

        echo "ERRO: ${PROGRAM} não encontrado:"
        echo "${PURGE}/${PROGRAM}"

        exit 1

    fi

done


if [ ! -f "${PURGE_SCRIPTS}/hist_plot.py" ]; then

    echo "AVISO: hist_plot.py não encontrado."
    echo "A análise continuará sem gerar o gráfico."

    HIST_AVAILABLE=false

else

    HIST_AVAILABLE=true

fi


# ============================================================
# 5.1 ALINHAMENTO
# ============================================================

echo
echo "============================================================"
echo "5.1 - ALINHAMENTO DAS READS"
echo "============================================================"
echo

echo "Executando minimap2..."

minimap2 \
    -x map-ont \
    -t "$THREADS_MAP" \
    "$FASTA" \
    "$READS" \
    | gzip > "$ALIGNMENT"

echo
echo "Alinhamento concluído:"
echo "$ALIGNMENT"


# ============================================================
# 5.2 CALCULAR COBERTURA E LIMIARES
# ============================================================

echo
echo "============================================================"
echo "5.2 - COBERTURA E LIMIARES"
echo "============================================================"
echo

cd "$OUTDIR"

echo "Executando pbcstat..."

"${PURGE}/pbcstat" \
    "$ALIGNMENT"


echo
echo "Arquivos gerados pelo pbcstat:"

ls -lh PB.*


echo
echo "Calculando cutoffs..."

"${PURGE}/calcuts" \
    PB.stat \
    > cutoffs \
    2> "$CALCUTS_LOG"


echo
echo "Cutoffs calculados:"
cat cutoffs


# ============================================================
# HISTOGRAMA
# ============================================================

if [ "$HIST_AVAILABLE" = true ]; then

    echo
    echo "Gerando histograma de cobertura..."

    python -m pip install matplotlib
    python "${PURGE_SCRIPTS}/hist_plot.py" \
        -c cutoffs \
        PB.stat \
        PB.cov.png

    mv PB.cov.png "$HIST_PLOT"

    echo
    echo "Histograma:"
    echo "$HIST_PLOT"

fi


# ============================================================
# 5.3 DIVIDIR MONTAGEM
# ============================================================

echo
echo "============================================================"
echo "5.3 - DIVIDINDO MONTAGEM"
echo "============================================================"
echo

"${PURGE}/split_fa" \
    "$FASTA" \
    > "$SPLIT_FA"

echo
echo "Split FASTA:"
echo "$SPLIT_FA"


# ============================================================
# 5.4 SELF ALIGNMENT
# ============================================================

echo
echo "============================================================"
echo "5.4 - SELF ALIGNMENT"
echo "============================================================"
echo

echo "Executando minimap2 self-alignment..."

minimap2 \
    -x asm5 \
    -DP \
    -t "$THREADS_SELF" \
    "$SPLIT_FA" \
    "$SPLIT_FA" \
    | gzip > "$SELF_PAF"

echo
echo "Self-alignment concluído:"
echo "$SELF_PAF"


# ============================================================
# 5.5 PURGE DUP
# ============================================================

echo
echo "============================================================"
echo "5.5 - PURGE DUPLICATIONS"
echo "============================================================"
echo


"${PURGE}/purge_dups" \
    -2 \
    -T cutoffs \
    -c PB.base.cov \
    "$SELF_PAF" \
    > "$DUPS_BED" \
    2> "$PURGE_LOG"


echo
echo "Duplicações identificadas:"
echo "$DUPS_BED"


# ============================================================
# 5.6 GERAR FASTA PURGADO
# ============================================================

echo
echo "============================================================"
echo "5.6 - GERANDO FASTA PURGADO"
echo "============================================================"
echo

"${PURGE}/get_seqs" \
    "$DUPS_BED" \
    "$FASTA"


# get_seqs gera purged.fa no diretório atual
if [ -f purged.fa ]; then

    mv purged.fa "$PURGED_FA"

else

    echo
    echo "ERRO: purged.fa não foi gerado."

    exit 1

fi


# ============================================================
# RESUMO
# ============================================================

echo
echo "============================================================"
echo "                 PURGE_DUPS CONCLUÍDO"
echo "============================================================"
echo
echo "Assembly original:"
echo "  $FASTA"
echo
echo "Reads:"
echo "  $READS"
echo
echo "Diretório de saída:"
echo "  $OUTDIR"
echo
echo "Arquivos principais:"
echo
echo "  Alignment:"
echo "    $ALIGNMENT"
echo
echo "  Cutoffs:"
echo "    ${OUTDIR}/cutoffs"
echo
echo "  Coverage:"
echo "    ${OUTDIR}/PB.base.cov"
echo
echo "  Self-alignment:"
echo "    $SELF_PAF"
echo
echo "  Duplicações:"
echo "    $DUPS_BED"
echo
echo "  FASTA purgado:"
echo "    $PURGED_FA"
echo
echo "============================================================"
