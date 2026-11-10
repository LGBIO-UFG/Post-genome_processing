#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# REMOÇÃO DE CONTIGS ORGANELARES
# Caryocar brasiliense
#
# Entrada:
#   1. FASTA do genoma
#   2. FASTA contendo cloroplasto + mtDNA
#
# Saída:
#   - tabela de classificação
#   - lista de contigs organelares
#   - FASTA sem contigs organelares
#
# Estratégia:
#   BLASTN do genoma contra as organelas
#   + cobertura do contig
#   + identidade
#   + cobertura da organela
#
# Contigs predominantemente organelares são removidos.
# Hits pequenos/parciais são mantidos para evitar remover
# regiões nucleares contendo NUMTs/NUPTs.
# ============================================================


# ============================================================
# CONFIGURAÇÃO
# ============================================================

GENOME="$1"
ORGANELLES="$2"

THREADS="${3:-20}"

OUTDIR="organelle_removal_telo_hap1"

mkdir -p "$OUTDIR"


# ============================================================
# VERIFICAÇÕES
# ============================================================

if [[ $# -lt 2 ]]; then
    echo ""
    echo "Uso:"
    echo "  bash remove_organelle_contigs.sh genome.fasta organelles.fasta [threads]"
    echo ""
    echo "Exemplo:"
    echo "  bash remove_organelle_contigs.sh Cbr_genome.fasta Cbr_organelles.fasta 40"
    echo ""
    exit 1
fi

command -v blastn >/dev/null 2>&1 || {
    echo "ERRO: blastn não encontrado."
    exit 1
}

command -v makeblastdb >/dev/null 2>&1 || {
    echo "ERRO: makeblastdb não encontrado."
    exit 1
}

command -v seqkit >/dev/null 2>&1 || {
    echo "ERRO: seqkit não encontrado."
    exit 1
}


echo ""
echo "============================================================"
echo " REMOÇÃO DE CONTIGS ORGANELARES"
echo "============================================================"
echo ""
echo "Genoma:       $GENOME"
echo "Organelas:    $ORGANELLES"
echo "Threads:      $THREADS"
echo "Output:       $OUTDIR"
echo ""


# ============================================================
# 1. PREPARAR BANCO BLAST
# ============================================================

echo "[1/7] Criando banco BLAST..."

makeblastdb \
    -in "$ORGANELLES" \
    -dbtype nucl \
    -parse_seqids \
    -out "$OUTDIR/organelles_db" \
    > "$OUTDIR/makeblastdb.log" \
    2>&1


# ============================================================
# 2. BLASTN
# ============================================================

echo "[2/7] Executando BLASTN..."

blastn \
    -query "$GENOME" \
    -db "$OUTDIR/organelles_db" \
    -out "$OUTDIR/genome_vs_organelles.tsv" \
    -outfmt '6 qseqid sseqid pident length qstart qend sstart send evalue bitscore qlen slen' \
    -evalue 1e-20 \
    -num_threads "$THREADS"


# ============================================================
# 3. PROCESSAR HITS
# ============================================================

echo "[3/7] Calculando cobertura e classificação..."

awk '
BEGIN {
    OFS="\t"
}

{
    q = $1
    s = $2
    pid = $3
    len = $4
    qlen = $11
    slen = $12

    qcov = (len / qlen) * 100
    scov = (len / slen) * 100

    score = qcov * pid

    if (!(q in best) || score > best[q]) {

        best[q] = score

        best_subject[q] = s
        best_pid[q] = pid
        best_len[q] = len
        best_qcov[q] = qcov
        best_scov[q] = scov
        best_bitscore[q] = $10
        best_qlen[q] = qlen
        best_slen[q] = slen
    }
}

END {

    print "contig",
          "organelle",
          "contig_length",
          "alignment_length",
          "identity",
          "contig_coverage",
          "organelle_coverage",
          "bitscore",
          "classification"

    for (q in best) {

        classification = "KEEP"

        if (best_pid[q] >= 90 && best_qcov[q] >= 80) {
            classification = "REMOVE"
        }
        else if (best_pid[q] >= 95 && best_qcov[q] >= 50) {
            classification = "REMOVE"
        }

        print q,
              best_subject[q],
              best_qlen[q],
              best_len[q],
              best_pid[q],
              best_qcov[q],
              best_scov[q],
              best_bitscore[q],
              classification
    }
}
' "$OUTDIR/genome_vs_organelles.tsv" \
> "$OUTDIR/contig_classification.tsv"


# ============================================================
# 4. GERAR LISTA DOS CONTIGS A REMOVER
# ============================================================

echo "[4/7] Gerando lista de contigs organelares..."

awk -F'\t' '
NR > 1 && $9 == "REMOVE" {
    print $1
}
' "$OUTDIR/contig_classification.tsv" \
> "$OUTDIR/contigs_to_remove.txt"


# ============================================================
# 5. GERAR LISTA DOS CONTIGS MANTIDOS
# ============================================================

awk -F'\t' '
NR > 1 && $9 == "KEEP" {
    print $1
}
' "$OUTDIR/contig_classification.tsv" \
> "$OUTDIR/contigs_to_keep.txt"


# ============================================================
# 6. REMOVER CONTIGS DO FASTA
# ============================================================

echo "[5/7] Removendo contigs organelares do FASTA..."

seqkit grep \
    -v \
    -f "$OUTDIR/contigs_to_remove.txt" \
    "$GENOME" \
    > "$OUTDIR/genome_without_organelles.fasta"


# ============================================================
# 7. ESTATÍSTICAS
# ============================================================

echo "[6/7] Calculando estatísticas..."

seqkit stats \
    "$GENOME" \
    "$OUTDIR/genome_without_organelles.fasta" \
    > "$OUTDIR/assembly_stats.tsv"


echo "[7/7] Resumo..."

N_TOTAL=$(grep -c '^>' "$GENOME" || true)

N_REMOVE=$(wc -l < "$OUTDIR/contigs_to_remove.txt")

N_KEEP=$(wc -l < "$OUTDIR/contigs_to_keep.txt")

N_FINAL=$(grep -c '^>' "$OUTDIR/genome_without_organelles.fasta" || true)


echo ""
echo "============================================================"
echo " RESULTADO"
echo "============================================================"
echo ""
echo "Contigs no genoma original:       $N_TOTAL"
echo "Contigs identificados como organelares: $N_REMOVE"
echo "Contigs mantidos:                 $N_KEEP"
echo "Contigs no FASTA final:           $N_FINAL"
echo ""
echo "Arquivos:"
echo ""
echo "  $OUTDIR/contig_classification.tsv"
echo "  $OUTDIR/contigs_to_remove.txt"
echo "  $OUTDIR/contigs_to_keep.txt"
echo "  $OUTDIR/genome_without_organelles.fasta"
echo "  $OUTDIR/assembly_stats.tsv"
echo ""
echo "============================================================"
echo " CONCLUÍDO"
echo "============================================================"
