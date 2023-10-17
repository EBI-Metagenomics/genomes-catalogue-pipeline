process MASH_COMPARE {

    tag "${cluster}"

    publishDir(
        "${params.outdir}/mash/${cluster}",
        mode: 'copy',
        failOnError: true
    )

    container 'quay.io/biocontainers/mash:2.3--hd3113c8_4'

    input:
    tuple val(cluster), path(many_genomes_fnas)

    output:
    path("${cluster}_mash.tsv"), emit: mash_split

    script:
    """
    mash sketch -o ${cluster}.msh ${many_genomes_fnas.join( ' ' )}
    mash dist ${cluster}.msh ${cluster}.msh > ${cluster}_mash_dist.tsv
    awk -F'\t' 'BEGIN {OFS=","} NR==1 {print "genome1", "genome2", "dist", "similarity"} NR>1 {print \$1, \$2, \$3, 1 - \$3}' < ${cluster}_mash_dist.tsv > ${cluster}_mash.tsv
    """
}
