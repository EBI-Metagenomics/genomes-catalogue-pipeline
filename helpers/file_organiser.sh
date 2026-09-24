#!/usr/bin/env bash

set -e

# The script organises output from the catalogue generation + Virify + Mobilome annotation pipeline to prepare it for upload to MGnify

function Usage {
    echo "Usage: $0 [-d /path/to/new/output/location] [-f ftp-folder-name] [-v catalogue-version] [-r /path/to/results/folder]"
    echo "Options:"
    echo "-d   Directory to save results to (FULL PATH)"
    echo "-f   FTP name of the catalogue, for example, human-oral or non-model-fish-gut"
    echo "-v   Catalogue version, for example, v1.0"
    echo "-r   Full path to nextflow pipeline results folder"
    exit 1
}

GET_REPS() {
    cat "$REPS_FILE"
}


# ---------------------------------------------------------------------------
# Slurm helpers
# ---------------------------------------------------------------------------

# Run a command on every file in a list as one Slurm job array, block until
# every task has finished, and exit if any task failed.
# Usage: RunArrayAndWait <job_name> <file_list> <mem> <concurrency> <command...>
RunArrayAndWait() {
    local job_name=$1 file_list=$2 mem=$3 concurrency=$4
    shift 4
    local n_files per_task n_tasks worker
    n_files=$(wc -l < "$file_list")
    if [[ $n_files -eq 0 ]]; then echo "${job_name}: nothing to do"; return 0; fi
    per_task=$(( (n_files + MAX_ARRAY_TASKS - 1) / MAX_ARRAY_TASKS ))
    n_tasks=$(( (n_files + per_task - 1) / per_task ))
    mkdir -p "$LOG_DIR"

    worker="${LOG_DIR}/${job_name}_worker.sh"
    cat > "$worker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
file_list=$1; per_task=$2; shift 2
start=$(( (SLURM_ARRAY_TASK_ID - 1) * per_task + 1 ))
end=$(( start + per_task - 1 ))
while read -r f; do
    "$@" "$f"
done < <(sed -n "${start},${end}p" "$file_list")
EOF

    echo "${job_name}: ${n_files} files across ${n_tasks} array tasks"
    if ! sbatch --wait -p production --mem="$mem" -t 24:00:00 --ntasks=1 \
            -J "$job_name" --array="1-${n_tasks}%${concurrency}" \
            -o "${LOG_DIR}/${job_name}_%A_%a.log" \
            "$worker" "$file_list" "$per_task" "$@"; then
        echo "ERROR: ${job_name} had failed tasks, see ${LOG_DIR}/${job_name}_*.log" >&2
        exit 1
    fi
}

# Stop rather than overwrite any existing .gz file
CheckNoGzConflicts() {
    local file_list=$1
    local conflicts="${file_list%.txt}_gz_conflicts.txt"
    : > "$conflicts"
    while read -r f; do
        if [[ -e "${f}.gz" ]]; then echo "$f" >> "$conflicts"; fi
    done < "$file_list"
    if [[ -s "$conflicts" ]]; then
        echo "ERROR: $(wc -l < "$conflicts") files already have a .gz next to them, see ${conflicts}" >&2
        exit 1
    fi
}

# Confirm every file in the list was replaced by a non-empty .gz
# (integrity is tested inside each job with gzip -t)
VerifyGzipped() {
    local file_list=$1 bad=0
    while read -r f; do
        if [[ -e "$f" || ! -s "${f}.gz" ]]; then
            echo "Not compressed correctly: $f" >&2
            bad=1
        fi
    done < "$file_list"
    if [[ $bad -ne 0 ]]; then echo "Verification failed, stopping." >&2; exit 1; fi
}

# Write a crash-safe gzip script. The original is only removed once a complete,
# verified .gz is on disk, so it is safe to rerun after an interruption at any point.
WriteSafeGzip() {
    mkdir -p "$LOG_DIR"
    cat > "${LOG_DIR}/safe_gzip.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
f=$1
tmp="${f}.gz.tmp"
dir=$(dirname "$f")

# Leftover from a job killed mid-compression: the original is still intact
rm -f "$tmp"

# Job killed after the .gz was finalised but before the original was removed:
# only delete the original if the .gz decompresses to exactly the same content
if [[ -e "${f}.gz" ]]; then
    if gzip -t "${f}.gz" && cmp -s <(gzip -dc "${f}.gz") "$f"; then
        rm "$f"
        exit 0
    fi
    echo "ERROR: ${f}.gz exists but does not match ${f}; leaving both untouched" >&2
    exit 1
fi

gzip -c "$f" > "$tmp"      # write to a temporary name first
gzip -t "$tmp"             # CRC check of the complete archive
sync "$tmp"                # make sure it is flushed to disk
mv "$tmp" "${f}.gz"        # atomic rename: a .gz only ever exists complete
sync "$dir"
rm "$f"                    # only now remove the original
EOF
}

# Wait for non-blocking jobs submitted earlier; fail if any of them failed
function WaitForBackgroundJobs {
    if [[ ${#BACKGROUND_JOBS[@]} -eq 0 ]]; then return 0; fi
    local deps
    deps=$(IFS=:; echo "${BACKGROUND_JOBS[*]}")
    echo "Waiting for background jobs: ${deps}"
    if ! sbatch --wait -p production --mem=100M -t 00:05:00 --ntasks=1 \
            -J wait_background_jobs \
            --dependency="afterok:${deps}" --kill-on-invalid-dep=yes \
            -o /dev/null --wrap="true"; then
        echo "ERROR: a background job failed, see ${LOG_DIR}/gzip_mgyg_genomes_*.log and ${LOG_DIR}/gzip_gene_catalogue_*.log" >&2
        exit 1
    fi
}


# ---------------------------------------------------------------------------
# Pipeline steps
# ---------------------------------------------------------------------------

function GenerateDirectories {
  if [[ -d "${SAVE_TO_PATH}" ]]
  then
      if [[ ! -d "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}" ]]
      then
          mkdir "${SAVE_TO_PATH}"/"${CATALOGUE_FOLDER}"
      fi
      if [[ -d "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}" ]]
      then
          echo "Directory ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION} already exists. Exiting."
          exit 1
      fi
      mkdir -p "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
      mkdir -p "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/"
  fi
}


function PrepareRun {
    mkdir -p "$LOG_DIR"

    export TMPDIR="${LOG_DIR}/tmp"
    mkdir -p "$TMPDIR"

    # Build the species representative list once. If this fails or comes back
    # empty, stop here instead of letting every later loop run over nothing.
    REPS_FILE="${LOG_DIR}/representatives.txt"
    cut -f14 "${RESULTS_PATH}/genomes-all_metadata.tsv" | grep -v "Species" | sort -u > "$REPS_FILE"
    local n_reps
    n_reps=$(wc -l < "$REPS_FILE")
    if [[ $n_reps -eq 0 ]]; then
        echo "ERROR: no species representatives found in ${RESULTS_PATH}/genomes-all_metadata.tsv" >&2
        exit 1
    fi
    echo "Found ${n_reps} species representatives"
}


function GzipSpeciesCatalogue {
    echo "Gzipping species catalogue files"
    local list="${LOG_DIR}/species_catalogue_files.txt"
    mkdir -p "$LOG_DIR"
    : > "$list"

    for R in $(GET_REPS); do
        local base="${RESULTS_PATH}/species_catalogue/${R::-2}/${R}"
        if [[ ! -d "${base}/genome" ]]; then
            echo "ERROR: missing genome folder for ${R}" >&2
            exit 1
        fi
        for sub in genome pan-genome; do
            # Singleton species have no pan-genome folder
            if [[ ! -d "${base}/${sub}" ]]; then continue; fi
            # The two annotated GFFs are excluded because later steps
            # rm/mv them by their uncompressed names
            find "${base}/${sub}" -type f \
                ! -name '*.gz' ! -name '*.gz.tmp' ! -name '*.fai' \
                ! -name "${R}_annotated.gff" \
                ! -name "${R}_annotated_with_mobilome.gff" >> "$list"
        done
    done

    # Existing .gz files are handled per file by safe_gzip.sh (removed only if
    # identical to the original, otherwise the run stops), so no pre-check here
    WriteSafeGzip
    RunArrayAndWait gzip_species_catalogue "$list" 10G 500 \
        bash "${LOG_DIR}/safe_gzip.sh"
    VerifyGzipped "$list"

    local leftovers
    leftovers=$(find "${RESULTS_PATH}/species_catalogue" -name '*.gz.tmp' | head -n 5)
    if [[ -n "$leftovers" ]]; then
        echo "ERROR: temporary files left behind, for example:" >&2
        echo "$leftovers" >&2
        exit 1
    fi
}


function GenerateWebsiteGFFs {
    echo "Generating GFFs for the website"
    cd "${RESULTS_PATH}/species_catalogue"
    for R in $(GET_REPS)
    do
        while read -r line
        do
            if [[ ${line} == "##FASTA" ]]
            then
                break
            else
                echo "$line"
            fi
        done < <(zcat "${R::-2}/${R}/genome/${R}_annotated_with_mobilome.gff.gz") > "${R::-2}/${R}/${R}.gff.noseq"
    done
}


function CopyWebsiteFiles {
    echo "Copying files to the website folder"
    set -o pipefail
    cd "${RESULTS_PATH}"
    cp phylo_tree.json "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/"
    cp catalogue_summary.json "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/"
    for R in $(GET_REPS)
    do
        cp -r "species_catalogue/${R::-2}/${R}" "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/"
    done
    echo "Cleaning up website folders"
    local website_gffs="${LOG_DIR}/website_gffs.txt"
    mkdir -p "$LOG_DIR"
    : > "$website_gffs"
    for R in $(GET_REPS)
    do
        rm -f "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}_annotated.gff"
        rm -f "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}_annotated_with_mobilome.gff.gz"
        rm -f "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}.fna.fai"
        zcat "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}.fna.gz" | singularity exec $SINGULARITY_CACHEDIR_PATH/community.wave.seqera.io-library-htslib_samtools_seqkit-049a7c2199a04854.img bgzip > "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}.fna.gz.tmp" \
        && mv "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}.fna.gz.tmp" "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}.fna.gz"
        mv "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/${R}.gff.noseq" "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}.gff"
        echo "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}.gff" >> "$website_gffs"
    done
    echo "Compressing and indexing website GFFs"
    CheckNoGzConflicts "$website_gffs"
    RunArrayAndWait bgzip_website_gffs "$website_gffs" 1G 100 \
        bash -c 'singularity run $SINGULARITY_CACHEDIR_PATH/community.wave.seqera.io-library-htslib_samtools_seqkit-049a7c2199a04854.img bgzip "$1" && singularity exec $SINGULARITY_CACHEDIR_PATH/community.wave.seqera.io-library-htslib_samtools_seqkit-049a7c2199a04854.img tabix -p gff -C "$1.gz"' _
    VerifyGzipped "$website_gffs"
}


function CopyFTPFiles {
    echo "Copying files to the FTP folder"
    cd "${RESULTS_PATH}"
    cp -r all_genomes* "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r gene_catalogue "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r genomes-all_metadata.tsv "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r kraken2_db* "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r phylogenies "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r protein_catalogue "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r README.txt "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/README_${CATALOGUE_VERSION}.txt"
    cp -r species_catalogue "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    for R in $(GET_REPS)
    do
        rm "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}_annotated.gff"
        mv "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}_annotated_with_mobilome.gff.gz" \
        "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}.gff.gz"
        rm "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/${R}.gff.noseq"
        # Replace the all_genomes GFF with a GFF that includes the mobilome
        rm "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/all_genomes/${R::-2}/${R}/genomes1/${R}.gff"
        cp "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}.gff.gz" \
        "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/all_genomes/${R::-2}/${R}/genomes1/"
    done
}


function CopyAdditionalFiles {
    echo "Copying additional files"
    cd "${RESULTS_PATH}"
    cp -r additional_data "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/"
    rm -f "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/additional_data/intermediate_files/ena_location_warnings.txt"
    mkdir -p "$LOG_DIR"
    local job_id

    # Submitted without --wait so they run alongside the rest of the script;
    # WaitForBackgroundJobs checks them at the end
    cd "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/additional_data"
    job_id=$(sbatch --parsable -p production --mem=1G -t 20:00:00 --ntasks=1 \
        -o "${LOG_DIR}/gzip_mgyg_genomes_%j.log" -J gzip_mgyg_genomes \
        --wrap="tar -czvf mgyg_genomes.tar.gz mgyg_genomes && rm -r mgyg_genomes")
    BACKGROUND_JOBS+=("${job_id%%;*}")

    cd "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/gene_catalogue"
    job_id=$(sbatch --parsable -p production --mem=1G -t 10:00:00 --ntasks=1 \
        -o "${LOG_DIR}/gzip_gene_catalogue_%j.log" -J gzip_gene_catalogue \
        --wrap="gzip gene_catalogue-100.ffn && gzip -t gene_catalogue-100.ffn.gz")
    BACKGROUND_JOBS+=("${job_id%%;*}")
}


function ZipAllGenomes {
    echo "Zipping files in the all_genomes folder"
    local list="${LOG_DIR}/all_genomes_gffs.txt"
    mkdir -p "$LOG_DIR"
    find "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/all_genomes" \
        -type f -path '*/genomes1/*' -name 'MGYG*gff' > "$list"
    CheckNoGzConflicts "$list"
    RunArrayAndWait gzip_all_genomes "$list" 1G 100 \
        bash -c 'gzip "$1" && gzip -t "$1.gz"' _
    VerifyGzipped "$list"
}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

while getopts 'd:f:v:r:s:' flag; do
    case "${flag}" in
        d) export SAVE_TO_PATH=$OPTARG ;;
        f) export CATALOGUE_FOLDER=$OPTARG ;;
        v) export CATALOGUE_VERSION=$OPTARG ;;
        r) export RESULTS_PATH=$OPTARG ;;
        s) export SINGULARITY_CACHEDIR_PATH=$OPTARG ;;
        *) Usage exit 1 ;;
    esac
done

if [[ -z $SAVE_TO_PATH ]] || [[ -z $CATALOGUE_FOLDER ]] || [[ -z $RESULTS_PATH ]] || [[ -z $CATALOGUE_VERSION ]]; then
  echo 'Not all of the arguments are provided'
  Usage
fi

LOG_DIR="${RESULTS_PATH}/reorganisation_slurm_logs"
MAX_ARRAY_TASKS=2000
BACKGROUND_JOBS=()

GenerateDirectories
PrepareRun
GzipSpeciesCatalogue
cd "${RESULTS_PATH}"
GenerateWebsiteGFFs
CopyWebsiteFiles
CopyFTPFiles
CopyAdditionalFiles
ZipAllGenomes
WaitForBackgroundJobs
cd "${RESULTS_PATH}"
echo "Script is done. All cluster jobs completed successfully."