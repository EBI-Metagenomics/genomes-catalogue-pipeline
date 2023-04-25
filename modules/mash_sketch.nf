process MASH_SKETCH {

    publishDir "${params.outdir}/", mode: 'copy'

    container 'quay.io/biocontainers/mash:2.3--hd3113c8_4 '

    input:
    path genomes_fasta

    output:
    path "all_genomes.msh", emit: all_genomes_msh

    script:
    """
    mash sketch -o all_genomes.msh ${genomes_fasta.join( ' ' )}
    """
}