process INDEX_FNA {

    tag "${cluster_name}"

    publishDir(
        "${params.outdir}",
        saveAs: {
            filename -> {
                String rep_name = filename.tokenize('.')[0];
                String cluste_prefix = cluster_name.substring(10);
                return "${params.outdir}/species_catalogue/${cluste_prefix}/${rep_name}/genome/$filename"
            }
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
