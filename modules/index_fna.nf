process INDEX_FNA {

    tag "${cluster_name}"

    publishDir(
        "${params.outdir}",
        saveAs: {
            filename -> "${params.catalogue_name}_metadata/${filename.tokenize('.')[0]}/genome/$filename"
        },
        mode: 'copy'
    )

    container "quay.io/biocontainers/samtools:1.9--h10a08f8_12"

    label 'process_light'

    cpus 1
    memory '500 MB'

    input:
    tuple val(cluster_name), file(fasta)

    output:
    path '*.fai', emit: fasta_index

    script:
    """
    samtools faidx ${fasta}
    """

    stub:
    """
    touch ${fasta.simpleName}.fai
    """
}
