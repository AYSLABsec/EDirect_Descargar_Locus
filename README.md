# EDirect_descarga_locus

Script interactivo en **Bash** para descargar **todas las secuencias disponibles** de un **gen o región** para un **taxón** usando utilidades de **NCBI EDirect**. Opcionalmente, puede complementar con **NCBI Datasets** cuando el objetivo sea un **gen con símbolo oficial** (p. ej., `rpoB`, `gyrB`).

> Esta versión (**v2**) prioriza estabilidad y simplicidad: flujo único `esearch | efetch`, prompts claros y salida en FASTA.

---

## ✨ Características

- Prompts interactivos: taxón, gen/región, base de datos destino (nuccore/protein) y filtros.
- Consulta robusta para **regiones/loci** (ej.: *ITS*, *COI*, *16S-V4*).
- Opción de descargar por **gen con símbolo oficial** (además de EDirect, ofrece NCBI Datasets si está instalado).
- Filtros prácticos:
  - `refseq[filter]` (opcional)
  - excluir `uncultured` / `environmental sample`
  - términos adicionales para **incluir** o **excluir**
- Salida directa en **FASTA** (`.fasta` / `.faa`), lista para análisis posterior.

---

## 📦 Requisitos

- **EDirect** (obligatorio): `esearch`, `efetch`
- **unzip** (recomendado)
- **NCBI Datasets** (opcional): `datasets` + `unzip` (solo si decides usar esa vía)

> Verifica:  
> `esearch -version` · `efetch -h | head -n 1` · `datasets --help` · `unzip -v`

---

## 🔧 Instalación

1) **Conda/Mamba** (recomendado)
```bash
# conda
conda install -c conda-forge -c bioconda entrez-direct

# o mamba
mamba install -c conda-forge -c bioconda entrez-direct
```

2) **Instalador oficial NCBI (Linux/macOS)**
```bash
sh -c "$(curl -fsSL https://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh)"
export PATH="$HOME/edirect:$PATH"
```

3) **Permisos del script**
```bash
chmod +x EDirect_descarga_locus_v2.sh
```

---

## 🚀 Uso rápido

Ejecuta el script y responde los prompts:

```bash
./EDirect_descarga_locus_v2.sh
```

Flujo típico de preguntas:

1. **Modo**  
   - `1) Región/locus` (p. ej., ITS, COI, 16S-V4)  
   - `2) Gen con símbolo oficial` (p. ej., rpoB, recA)
2. **Taxón** (p. ej., `Trichoderma`, `Bacillus`)
3. **Gen o región** (p. ej., `ITS`, `rpoB`)
4. **Base de datos**  
   - `nuccore` (nucleótidos)  
   - `protein` (proteínas)
5. **Filtros**  
   - `refseq[filter]` (s/n)  
   - excluir `uncultured/environmental sample` (S/n)  
   - términos extra a **incluir/excluir**
6. **Nombre de archivo de salida** (FASTA)

---

## 🧠 Lógica de la consulta

- **Región/locus (ej. ITS):** el script arma una consulta amplia y compatible con EDirect, incluyendo sinónimos cuando corresponde (p. ej., *internal transcribed spacer* para ITS), y aplica filtros según tus respuestas.
- **Gen con símbolo oficial:** el script usa EDirect (y te ofrece **NCBI Datasets** si detecta `datasets` y `unzip`) para traer **gene/CDS/protein** estructurados además del FASTA general.

> Nota: Para marcadores como **ITS**, muchas entradas **no** están en RefSeq; si buscas cobertura máxima, suele ser mejor **no** activar `refseq[filter]`.

---

## 📄 Salida

- Archivo FASTA con el nombre que indiques (p. ej., `Trichoderma_ITS_nuccore.fasta` o `Bacillus_rpoB_protein.faa`).
- Si usas NCBI Datasets, se crea además un ZIP y una carpeta con **FASTA/JSON/tablas** de genes/CDS/proteínas para ese símbolo.

---

## 🧪 Ejemplos

### 1) ITS en *Trichoderma* (nucleótidos)
- Modo: `1) Región/locus`  
- Taxón: `Trichoderma`  
- Gen o región: `ITS`  
- DB: `nuccore`  
- RefSeq: `n` (recomendado para ITS)  
- Excluir uncultured/env sample: a tu criterio (por defecto `S`)  
- Salida: `Trichoderma_ITS_nuccore.fasta`

### 2) rpoB en *Bacillus* (proteínas) + Datasets
- Modo: `2) Gen con símbolo oficial`  
- Taxón: `Bacillus`  
- Gen: `rpoB`  
- DB: `protein`  
- Aceptar intento con NCBI Datasets: `s`  
- Salida: `Bacillus_rpoB_protein.faa` + carpeta de Datasets

---

## 🔍 Post-procesamiento sugerido

Con **seqkit** (opcional):

```bash
# Resumen
seqkit stats Trichoderma_ITS_nuccore.fasta

# Deduplicar por secuencia
seqkit rmdup -s Trichoderma_ITS_nuccore.fasta > Trichoderma_ITS_nuccore.dedup.fasta

# Filtrar por longitud (ej. ITS entre 300–900 nt)
seqkit seq -m 300 -M 900 Trichoderma_ITS_nuccore.fasta > Trichoderma_ITS_300-900.fasta
```

---

## 🆘 Solución de problemas

- **“ERROR: faltan utilidades de EDirect (esearch/efetch)”**  
  Instala EDirect (ver arriba) y asegúrate de que tu shell cargue el `PATH` correcto.

- **Advertencia `PhraseIgnored: its`**  
  Sucede si `ITS` se interpreta como palabra suelta. La versión actual del script etiqueta campos y añade sinónimos para evitarlo. Si lo ves, simplemente continúa; la consulta ajustada suele devolver resultados.

- **0 resultados, pero debería haber**  
  - Verifica el **taxón** (usa nombres científicos válidos).  
  - Prueba **sin `refseq[filter]`** para marcadores (ITS/COI).  
  - Quita filtros de exclusión o términos excesivamente específicos.

- **Descargas grandes (miles de registros)**  
  Esta versión usa un único flujo `esearch | efetch`. Si tu red corta o limita, puedes pedirme una **versión paginada** (con `WebEnv/QueryKey` y bloques `retmax`) para máxima robustez.

- **NCBI Datasets falla**  
  Puede ser por símbolo de gen no válido para ese taxón o por no tener `datasets`/`unzip`. El script seguirá con EDirect igualmente.

---

## 🧩 Notas y buenas prácticas

- **Regiones/loci** (ITS/COI/16S-V4): suelen estar abundantemente en **GenBank**, no siempre en RefSeq → considera **no** activar `refseq[filter]`.
- **Genes con símbolo oficial**: si quieres **CDS/proteínas/metadatos** limpios, prueba la opción con **NCBI Datasets** además del FASTA general.
- **Reproducibilidad**: guarda el **taxón**, el **marcador** y la **consulta** usada (el propio script imprime la query final para auditoría).
- **Términos extra**:  
  - Incluir: \"complete cds\", barcode, etc.  
  - Excluir: partial, mitochondrial, etc.

---

## 📝 Licencia

MIT (o la que prefieras). Añade aquí el texto de licencia si procede.

---

## 👤 Autoría y soporte

- Área de trabajo de Investigación y Desarrollo — AYSLAB  
- ¿Necesitas una **versión no interactiva** (flags `--taxon`, `--marker`, `--db`, etc.) o la **versión paginada** para lotes grandes? Escríbeme y te la preparo.
