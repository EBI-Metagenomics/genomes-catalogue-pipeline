process MASH_SKETCH {

    publishDir "${params.outdir}/", mode: 'copy', failOnError: true

    container 'quay.io/biocontainers/mash:2.3--hb105d93_10'

    input:
    path genomes_fasta

    output:
    path "all_genomes.msh", emit: all_genomes_msh

    script:
    """
    find . -name "MGYG*.fna" > list.txt
    mash sketch -o all_genomes.msh -l list.txt -p ${task.cpus} 
    """
}
