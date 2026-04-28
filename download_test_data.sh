#!/usr/bin/env bash
#
# download_test_data.sh
# ---------------------
# Downloads three paired-end RNA-seq test samples from the nf-core test-datasets
# repository into ./data/. Files are tiny (~50,000 reads each, sub-sampled from
# S. cerevisiae GSE110004) so the whole pipeline finishes in seconds.
#
# Source study:
#   Wu et al. 2018, Mol Cell. "Repression of Divergent Noncoding Transcription
#   by a Sequence-Specific Transcription Factor." (GSE110004)

set -euo pipefail   # exit on error, undefined var, or failed pipe

# Where files come from and where they go.
BASE_URL="https://raw.githubusercontent.com/nf-core/test-datasets/rnaseq/testdata/GSE110004"
DATA_DIR="data"

# Three wild-type replicates, paired-end (R1 + R2 each = 6 files total).
SAMPLES=(SRR6357070 SRR6357071 SRR6357072)

mkdir -p "${DATA_DIR}"
cd "${DATA_DIR}"

echo "Downloading test FASTQs into $(pwd)..."
for sample in "${SAMPLES[@]}"; do
    for read in 1 2; do
        file="${sample}_${read}.fastq.gz"
        if [[ -f "${file}" ]]; then
            echo "  [skip] ${file} already exists"
        else
            echo "  [get ] ${file}"
            curl -fsSL -o "${file}" "${BASE_URL}/${file}"
        fi
    done
done

echo
echo "Done. Files in ${DATA_DIR}/:"
ls -lh
