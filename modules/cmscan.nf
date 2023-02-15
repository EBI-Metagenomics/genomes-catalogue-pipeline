/*
 * cmscan
*/
process CMSCAN {

    label 'process_medium'

    container 'quay.io/microbiome-informatics/genomes-pipeline.detect_rrna:v3'

    // TODO, check if needed
    publishDir '${params.outdir}/cmscan', mode:'copy'

    memory '5 GB'
    cpus 4

    input:
    path contigs
    file claninfo
    path rnafammodel
    file contigs

    output:
    path '*.cmscan.deoverlap.tbl', emit: tblout

    script:
    """
    cmscan --cpu ${task.cpus} \
    --tblout overlapped_${contigs.baseName} \
    --clanin ${claninfo} \
    --hmmonly \
    --fmt 2 \
    --cut_ga \
    --noali -o /dev/null \
    ${rnafammodel}/Rfam.cm \
    ${contigs}

    # De-overlap #
    grep -v " = " overlapped_${contigs.baseName} > ${contigs.baseName}.cmscan.deoverlap.tbl
    """
}
