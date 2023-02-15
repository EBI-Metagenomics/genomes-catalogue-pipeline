
process DETECT_NCRNA {

    publishDir "results/ncrna/${cluster_name}/", mode: 'copy'

    container 'quay.io/microbiome-informatics/genomes-pipeline.detect_rrna:v3'

    cpus 4
    memory '5 GB'

    input:
    tuple val(cluster_name), path(fasta)
    path rfam_ncrna_models

    output:
    tuple val(cluster_name), path('*.ncrna.deoverlap.tbl'), emit: ncrna_tblout

    script:
    """
    cmscan \
    --cpu ${task.cpus} \
    --tblout overlapped_${fasta.baseName} \
    --hmmonly \
    --clanin ${rfam_ncrna_models}/Rfam.clanin \
    --fmt 2 \
    --cut_ga \
    --noali \
    -o /dev/null \
    ${rfam_ncrna_models}/Rfam.cm \
    ${fasta}

    # De-overlap #
    grep -v " = " overlapped_${fasta.baseName} > ${fasta.baseName}.ncrna.deoverlap.tbl
    """
}
