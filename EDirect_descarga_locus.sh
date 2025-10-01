#!/usr/bin/env bash
# EDirect_descarga_locus_v2.sh
set -euo pipefail

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# Dependencias mínimas
if ! has_cmd esearch || ! has_cmd efetch; then
  printf '%s\n' 'ERROR: faltan utilidades de EDirect (esearch/efetch). Instálalas y vuelve a ejecutar.'
  exit 1
fi

DATASETS_OK=1
if ! has_cmd datasets || ! has_cmd unzip; then
  DATASETS_OK=0
fi

printf '%s\n' "============================================================"
printf '%s\n' " Descarga de secuencias por GEN o REGIÓN para un TAXÓN"
printf '%s\n' "============================================================"
printf '\n'

# 1) Modo
printf '%s\n' "¿Qué quieres descargar?"
printf '%s\n' "  1) Región/locus (p.ej., ITS, COI, 16S-V4)  -> recomendado: EDirect"
printf '%s\n' "  2) Gen con símbolo oficial (p.ej., rpoB)   -> EDirect o NCBI Datasets"
read -rp "Elige 1 o 2 [1]: " MODE
MODE="${MODE:-1}"

# 2) Entradas
read -rp "Taxón (p.ej., Trichoderma): " TAXON
read -rp "Gen o región (p.ej., ITS o rpoB): " MARKER

# 3) Base
printf '%s\n' "Base a descargar:"
printf '%s\n' "  1) Núcleo (nuccore, nucleótidos)"
printf '%s\n' "  2) Proteínas (protein)"
read -rp "Elige 1 o 2 [1]: " DBSEL
DBSEL="${DBSEL:-1}"
DB="nuccore"
if [[ "$DBSEL" == "2" ]]; then DB="protein"; fi

# 4) Filtros
read -rp "¿Restringir a RefSeq? (añade refseq[filter]) [s/N]: " REFSEQ
REFSEQ="${REFSEQ:-N}"
read -rp "¿Excluir 'uncultured' y 'environmental sample'? [S/n]: " EXC
EXC="${EXC:-S}"

# 5) Términos extra
read -rp "Términos extra a REQUERIR (ej. \"complete cds\") [ENTER para ninguno]: " EXTRA_INCL
read -rp "Términos a EXCLUIR (ej. \"partial\") [ENTER para ninguno]: " EXTRA_EXCL

# 6) Salida
DEFAULT_OUT="$(printf '%s' "${TAXON}_${MARKER}_${DB}.fasta" | tr ' ' '_')"
read -rp "Archivo de salida [${DEFAULT_OUT}]: " OUT
OUT="${OUT:-$DEFAULT_OUT}"

# Función para construir query segura
build_query() {
  local tax="$1" marker="$2" db="$3" refseq="$4" exc="$5" incl="$6" excl="$7"
  local q_base="" q_ref="" q_exc="" q_incl="" q_excl=""

  # Normalizar minúsculas (requiere bash >=4)
  local marker_lc="${marker,,}"

  if [[ "$db" == "protein" ]]; then
    q_base="${tax}[Organism] AND ${marker}[Gene Name]"
  else
    if [[ "$marker_lc" =~ ^its([0-9]|s|$) ]]; then
      q_base="${tax}[Organism] AND (${marker} OR \"internal transcribed spacer\")"
    else
      q_base="${tax}[Organism] AND ${marker}"
    fi
  fi

  if [[ "$refseq" =~ ^[sS]$ ]]; then
    q_ref=" AND refseq[filter]"
  fi

  if [[ "$exc" =~ ^[sS]$ ]]; then
    q_exc=" NOT (uncultured OR environmental sample)"
  fi

  if [[ -n "$incl" ]]; then
    q_incl=" AND (${incl})"
  fi

  if [[ -n "$excl" ]]; then
    # unir palabras por OR para exclusión robusta
    local q_excl_words
    q_excl_words="$(printf '%s' "$excl" | sed 's/[[:space:]]\+/ OR /g')"
    q_excl=" NOT (${q_excl_words})"
  fi

  printf '%s' "${q_base}${q_ref}${q_exc}${q_incl}${q_excl}"
}

QUERY="$(build_query "$TAXON" "$MARKER" "$DB" "$REFSEQ" "$EXC" "$EXTRA_INCL" "$EXTRA_EXCL")"

printf '\n%s\n' "------------------------------------------------------------"
printf '%s\n' "Consulta EDirect construida:"
printf '  %s %s\n' "DB :" "$DB"
printf '  %s %s\n' "QRY:" "$QUERY"
printf '  %s %s\n' "OUT:" "$OUT"
printf '%s\n' "------------------------------------------------------------"
printf '\n'

# Ofrecer datasets si aplica
USE_DATASETS=0
if [[ "$MODE" == "2" && "$DATASETS_OK" -eq 1 ]]; then
  printf '%s\n' "Opcional: usar NCBI Datasets para GEN con símbolo oficial."
  printf '%s\n' "Ventajas: gene/CDS/protein y metadatos."
  read -rp "¿Intentar con NCBI Datasets? [s/N]: " WANT_DS
  WANT_DS="${WANT_DS:-N}"
  if [[ "$WANT_DS" =~ ^[sS]$ ]]; then USE_DATASETS=1; fi
elif [[ "$MODE" == "2" && "$DATASETS_OK" -eq 0 ]]; then
  printf '%s\n' "(NCBI Datasets no disponible: instala 'datasets' y 'unzip' si quieres esa vía.)"
fi

if [[ "$USE_DATASETS" -eq 1 ]]; then
  ZIPNAME="$(printf '%s' "${TAXON}_${MARKER}_datasets.zip" | tr ' ' '_')"
  OUTDIR="$(printf '%s' "${TAXON}_${MARKER}_datasets" | tr ' ' '_')"

  printf '\n%s\n' "Descargando con NCBI Datasets (gene symbol=${MARKER}, taxon=${TAXON})..."
  set +e
  datasets download gene symbol "${MARKER}" \
    --taxon "${TAXON}" \
    --include gene,cds,protein \
    --filename "${ZIPNAME}"
  DS_STATUS=$?
  set -e

  if [[ $DS_STATUS -ne 0 ]]; then
    printf '%s\n' "Fallo NCBI Datasets. Continuamos con EDirect..."
  else
    mkdir -p "${OUTDIR}"
    unzip -o "${ZIPNAME}" -d "${OUTDIR}" >/dev/null
    printf '%s\n' "Contenido extraído en: ${OUTDIR}/"
    printf '%s\n' "Seguimos con EDirect para captar TODO lo disponible en ${DB}."
  fi
fi

# Descarga principal con EDirect
printf '\n%s\n' "Descargando con EDirect (puede tardar si la consulta es amplia)..."
esearch -db "$DB" -query "$QUERY" | efetch -format fasta > "$OUT"

# Conteo de líneas seguro
LINES=$(wc -l < "$OUT" || printf '0')
printf '%s\n' "------------------------------------------------------------"
printf '%s\n' "Listo."
printf '  %s %s\n' "Archivo FASTA:" "$OUT"
printf '  %s %s\n' "Líneas en archivo:" "$LINES"
if [[ "${USE_DATASETS:-0}" -eq 1 && -d "${OUTDIR:-.}" ]]; then
  printf '  %s %s\n' "Carpeta Datasets:" "${OUTDIR}/"
fi
printf '%s\n' "Sugerencia: revisa cabeceras; puedes depurar con seqkit/awk."
printf '%s\n' "------------------------------------------------------------"
