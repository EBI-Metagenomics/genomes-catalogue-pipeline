process REDMASK {

    tag "${output_prefix}"

    container 'quay.io/microbiome-informatics/red:2.0'

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> "softmasked_genome/$filename"
        },
        mode: "copy",
        failOnError: true
    )

    input:
    path genome_folder // folder/genome.fasta

    output:
    tuple path("*_sm.fasta"), emit: masked_fasta

    script:
    """
    genome_name=$(basename ${genome_folder}/*fasta .fasta)
    cp ${genome_folder}/${genome_name}.fasta ${genome_folder}/${genome_name}.fa

    mkdir masked_genomes
    Red -gnm ${genome_folder}/ -msk masked_genomes/

    mv masked_genomes/${genome_name} ${genome_name}_sm.fasta
    """
}

//softmask repeats in the genome with Red (REpeatDetector)
