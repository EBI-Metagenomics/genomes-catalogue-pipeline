process MASH_COMPARE {

    tag "${cluster}"

    publishDir(
        "${params.outdir}/mash/${cluster}",
        mode: 'copy',
        failOnError: true
    )

    container 'quay.io/biocontainers/mash:2.3--hd3113c8_4 '

    input:
    tuple val(cluster), path(many_genomes_fnas)

    output:
    tuple val(cluster), path "${cluster}_mash.tsv", emit: mash_split

    script:
    """
    mash sketch -o ${cluster}.msh ${many_genomes_fnas.join( ' ' )}
    mash dist ${cluster}.msh > ${cluster}_mash.tsv
    """
}
