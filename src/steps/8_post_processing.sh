#!/bin/bash

usage() {
    cat <<EOF
usage: $0 options
Run the post-processing step. This is one of the two temporary replacement steps for 8_post_processing.sh
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -j      LSF step Job name to submit
   -b      Biome lineage
EOF
}

set -e

while getopts ho:p:l:n:q:j:b: option; do
    case "${option}" in
    h)
        usage
        exit 1
        ;;
    o)
        OUT=${OPTARG}
        ;;
    p)
        P=${OPTARG}
        ;;
    l)
        LOGS=${OPTARG}
        ;;
    n)
        DIRNAME=${OPTARG}
        ;;
    q)
        QUEUE=${OPTARG}
        ;;
    j)
        JOB=${OPTARG}
        ;;
    b)
        BIOME=${OPTARG}
        ;;
    ?)
        usage
        exit
        ;;
    esac
done

. /hps/software/users/rdf/metagenomics/service-team/repos/mi-automation/team_environments/codon/mitrc.sh

REP_ACCS_SG=$(cat "${OUT}"/cluster_reps.txt.sg)
REP_ACCS_PG=$(cat "${OUT}"/cluster_reps.txt.pg)

mkdir -p "${LOGS}/post-processing"

# Restructure SanntiS output
bash "${PIPELINE_DIRECTORY}"/bin/restructure_sanntis.sh -o "${OUT}" -n "${DIRNAME}"

# Copy annotations into the metadata folder and run post-processing for singletons
for ACC in $REP_ACCS_SG; do
    mkdir -p "${OUT}"/"${DIRNAME}"_metadata/"${ACC}" && mkdir -p "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/
    cp "${OUT}"/sg/"${ACC}"_cluster/"${ACC}"/"${ACC}".fna "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/
    cp "${OUT}"/sg/"${ACC}"_cluster/"${ACC}"/"${ACC}".faa "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/
    cp "${OUT}"/sg/"${ACC}"_cluster/"${ACC}"/"${ACC}".gff "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/

    # Generate annotation summaries
    bsub -J "${JOB}"_"${DIRNAME}"_summary_"${ACC}" \
    -q "${QUEUE}" \
    -n 1 \
    -M 1G -o \
        "${LOGS}"/post-processing/"${JOB}"_"${DIRNAME}"_summary_"${ACC}".log python3 \
        "${PIPELINE_DIRECTORY}"/docker/genomes-catalog-update/scripts/generate_annots.py -i "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/ \
        -a "${OUT}"/"${DIRNAME}"_annotations/"${ACC}"_InterProScan.tsv \
        "${OUT}"/"${DIRNAME}"_annotations/"${ACC}"_eggNOG.tsv \
        -k "${KEGG_CLASSES_TSV}" \
        -o "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/

    sleep 2

    # Run cmscan
    CLANIN="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/ncrna_cms/Rfam.clanin"
    RFAM="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/ncrna_cms/Rfam.cm"

    bsub -J "${ACC}"_cmscan -q "${QUEUE}" \
    -n 4 -M 5G \
    -o "${LOGS}"/post-processing/"${ACC}"-cmscan.log \
    singularity exec \
    $SINGULARITY_CACHEDIR/quay.io_microbiome-informatics_genomes-pipeline.detect_rrna:v3.sif cmscan --cpu 4 \
    --tblout "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}".cmscan --hmmonly --clanin ${CLANIN} --fmt 2 \
    --cut_ga --noali -o /dev/null ${RFAM} "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}".fna

    bsub -w "ended("${ACC}"_cmscan)" \
    -J "${ACC}"_deoverlap \
    -q "${QUEUE}" -n 1 \
    -M 5G \
    -o "${LOGS}"/post-processing/"${ACC}"-deoverlap.log \
        bash "${PIPELINE_DIRECTORY}"/docker/bash/remove_overlaps_cmscan.sh -i \
        "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}".cmscan \
        -o "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}".deoverlap

    sleep 2

    # Run GFF annotation
    bsub -w "ended("${ACC}"_deoverlap)" \
    -J "${ACC}"_annotgff -q "${QUEUE}" \
    -n 1 -M 5G \
    -o "${LOGS}"/post-processing/"${ACC}"-gff-annot.log \
        python3 "${PIPELINE_DIRECTORY}"/docker/genomes-catalog-update/scripts/annot_gff.py -i "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/ \
        -a "${OUT}"/"${DIRNAME}"_annotations/"${ACC}"_InterProScan.tsv \
        "${OUT}"/"${DIRNAME}"_annotations/"${ACC}"_eggNOG.tsv \
        "${OUT}"/"${DIRNAME}"_annotations/"${ACC}".gbk.sanntis.full.gff \
        -r "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}".deoverlap -o "${OUT}"/"${DIRNAME}"_metadata/"${ACC}".gff

    sleep 2

    # Index fna
    cd "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/
    bsub -J "${ACC}"_index_fasta -q "${QUEUE}" \
    -n 1 -M 1G \
    -o "${LOGS}"/post-processing/"${ACC}"-index-fasta.log \
        singularity run $SINGULARITY_CACHEDIR/quay.io_microbiome-informatics_genomes-pipeline.bash:v1.sif index_fasta.sh \
        -f "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/${ACC}.fna

    sleep 2

    # Make genome.json
    bsub -w "ended("${ACC}"_annotgff)" -J "${ACC}"_json \
    -q "${QUEUE}" -n 1 -M 5G \
    -o "${LOGS}"/post-processing/"${ACC}"-json.log \
        python3 "${PIPELINE_DIRECTORY}"/docker/genomes-catalog-update/scripts/generate_stats_json.py --annot-cov \
        "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}"_annotation_coverage.tsv --gff \
        "${OUT}"/"${DIRNAME}"_metadata/"${ACC}".gff -m "${OUT}"/"${DIRNAME}"_metadata/genomes-all_metadata.tsv -b "${BIOME}" \
        -s "${ACC}" -o "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/"${ACC}".json -i "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/ \
        --cluster-structure

    sleep 2

    bsub -w "ended("${ACC}"_json)" \
    -q "${QUEUE}" \
    -n1 -M 50 -o /dev/null \
    "cp ${OUT}/${DIRNAME}_annotations/${ACC}* \
    ${OUT}/${DIRNAME}_metadata/${ACC}/genome/"
    
    bsub -w "ended("${ACC}"_json)" \
    -q "${QUEUE}" -n1 -M 50 \
    -o /dev/null "cp "${OUT}"/"${DIRNAME}"_metadata/"${ACC}".gff ${OUT}/${DIRNAME}_metadata/${ACC}/genome/"
    
    bsub -w "ended("${ACC}"_json)" \
    -q "${QUEUE}" -n1 -M 50 -o /dev/null \
    "rm ${OUT}/${DIRNAME}_metadata/${ACC}/genome/${ACC}.deoverlap"
    
    bsub -w "ended("${ACC}"_json)" \
    -q "${QUEUE}" -n1 -M 50 -o /dev/null \
    "rm ${OUT}/${DIRNAME}_metadata/${ACC}/genome/${ACC}.cmscan"

    sleep 5
done

# Copy annotations into the metadata folder and run post-processing for pan-genomes

for ACC in $REP_ACCS_PG; do
    mkdir -p "${OUT}"/"${DIRNAME}"_metadata/"${ACC}" && mkdir -p "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/
    cp "${OUT}"/pg/"${ACC}"_cluster/"${ACC}"/"${ACC}".fna "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/
    cp "${OUT}"/pg/"${ACC}"_cluster/"${ACC}"/"${ACC}".faa "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/
    cp "${OUT}"/pg/"${ACC}"_cluster/"${ACC}"/"${ACC}".gff "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/
    mkdir -p "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/pan-genome/
    cp "${OUT}"/pg/"${ACC}"_cluster/"${ACC}"/"${ACC}".core_genes.txt "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/pan-genome/
    cp "${OUT}"/pg/"${ACC}"_cluster/"${ACC}"/"${ACC}"_mashtree.nwk "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/pan-genome/
    cp "${OUT}"/pg/"${ACC}"_cluster/"${ACC}"/"${ACC}".pan-genome.fna "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/pan-genome/

    # Generate annotation summaries
    bsub -J "${JOB}"_"${DIRNAME}"_summary_"${ACC}" \
    -q "${QUEUE}" -n 1 -M 1G -o \
        "${LOGS}"/post-processing/"${JOB}"_"${DIRNAME}"_summary_"${ACC}".log python3 \
        "${PIPELINE_DIRECTORY}"/docker/genomes-catalog-update/scripts/generate_annots.py -i "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/ \
        -a "${OUT}"/"${DIRNAME}"_annotations/"${ACC}"_InterProScan.tsv \
        "${OUT}"/"${DIRNAME}"_annotations/"${ACC}"_eggNOG.tsv \
        -k /hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/kegg_classes.tsv \
        -o "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/

    # Run cmscan
    CLANIN="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/ncrna_cms/Rfam.clanin"
    RFAM="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/ncrna_cms/Rfam.cm"

    sleep 2

    bsub -J "${ACC}"_cmscan -q "${QUEUE}" -n 4 -M 5G -o "${LOGS}"/post-processing/"${ACC}"-cmscan.log "singularity exec \
  $SINGULARITY_CACHEDIR/quay.io_microbiome-informatics_genomes-pipeline.detect_rrna:v3.sif cmscan --cpu 4 \
  --tblout "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}".cmscan --hmmonly --clanin ${CLANIN} --fmt 2 \
  --cut_ga --noali -o /dev/null ${RFAM} "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}".fna"

    bsub -w "ended("${ACC}"_cmscan)" -J "${ACC}"_deoverlap -q "${QUEUE}" -n 1 -M 5G -o "${LOGS}"/post-processing/"${ACC}"-deoverlap.log \
        bash "${PIPELINE_DIRECTORY}"/docker/bash/remove_overlaps_cmscan.sh -i "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}".cmscan \
        -o "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}".deoverlap

    sleep 2

    # Run GFF annotation
    bsub -w "ended("${ACC}"_deoverlap)" -J "${ACC}"_annotgff -q "${QUEUE}" -n 1 -M 5G -o "${LOGS}"/post-processing/"${ACC}"-gff-annot.log \
        python3 "${PIPELINE_DIRECTORY}"/docker/genomes-catalog-update/scripts/annot_gff.py -i "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/ \
        -a "${OUT}"/"${DIRNAME}"_annotations/"${ACC}"_InterProScan.tsv \
        "${OUT}"/"${DIRNAME}"_annotations/"${ACC}"_eggNOG.tsv \
        "${OUT}"/"${DIRNAME}"_annotations/"${ACC}".gbk.sanntis.full.gff \
        -r "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}".deoverlap -o "${OUT}"/"${DIRNAME}"_metadata/"${ACC}".gff

    sleep 2

    # Index fna
    cd "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/
    bsub -J "${ACC}"_index_fasta -q "${QUEUE}" -n 1 -M 1G -o "${LOGS}"/post-processing/"${ACC}"-index-fasta.log \
        singularity run $SINGULARITY_CACHEDIR/quay.io_microbiome-informatics_genomes-pipeline.bash:v1.sif index_fasta.sh \
        -f "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/${ACC}.fna

    sleep 2

    # Make genome.json
    bsub -w "ended("${ACC}"_annotgff)" -J "${ACC}"_json -q "${QUEUE}" -n 1 -M 5G -o "${LOGS}"/post-processing/"${ACC}"-json.log \
        python3 "${PIPELINE_DIRECTORY}"/docker/genomes-catalog-update/scripts/generate_stats_json.py --annot-cov \
        "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/genome/"${ACC}"_annotation_coverage.tsv --gff \
        "${OUT}"/"${DIRNAME}"_metadata/"${ACC}".gff -m "${OUT}"/"${DIRNAME}"_metadata/genomes-all_metadata.tsv -b "${BIOME}" \
        -s "${ACC}" -o "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/"${ACC}".json -i "${OUT}"/"${DIRNAME}"_metadata/"${ACC}"/ \
        --cluster-structure

    sleep 2

    bsub -w "ended("${ACC}"_json)" -q "${QUEUE}" -n1 -M 50 -o /dev/null "cp ${OUT}/${DIRNAME}_annotations/${ACC}* \
  ${OUT}/${DIRNAME}_metadata/${ACC}/genome/"
    bsub -w "ended("${ACC}"_json)" -q "${QUEUE}" -n1 -M 50 -o /dev/null "cp "${OUT}"/"${DIRNAME}"_metadata/"${ACC}".gff ${OUT}/${DIRNAME}_metadata/${ACC}/genome/"
    bsub -w "ended("${ACC}"_json)" -q "${QUEUE}" -n1 -M 50 -o /dev/null "rm ${OUT}/${DIRNAME}_metadata/${ACC}/genome/${ACC}.deoverlap"
    bsub -w "ended("${ACC}"_json)" -q "${QUEUE}" -n1 -M 50 -o /dev/null "rm ${OUT}/${DIRNAME}_metadata/${ACC}/genome/${ACC}.cmscan"

    sleep 5
done
