process MASH_SKETCH {

    container 'quay.io/biocontainers/mash:2.3--hd3113c8_4 '

    input:
    path genomes_fasta

    output:
    file "all_genomes.msh"

    script:
    """
    sketch -o all_genomes.msh ${genomes_fasta.join( ' ' )}
    """
}