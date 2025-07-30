process REPEAT_MASKER {
    tag "${genome.baseName}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://dfam/tetools:latest' :
        'dfam/tettools:latest' }"


    input:
    tuple val(genome_name), path(genome), path(proteins)
    tuple val(genome_name), path(library)

    output:
    tuple val(genome_name), path("${genome.baseName}_sm.fa"), emit: masked_genome 

    script:
    """
    RepeatMasker -lib ${library} -xsmall ${genome} -pa ${task.cpus}

    mv *.masked "${genome.baseName}_sm.fa"
    """
}
