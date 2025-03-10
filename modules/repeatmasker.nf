process REPEAT_MASKER {
    tag "$meta.id"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://dfam/tetools:latest' :
        'dfam/tettools:latest' }"


    input:
    tuple val(meta), path(genome)
    tuple val(meta), path(library)

    output:
    tuple val(meta), path("*_sm.fa"), emit: masked_genome 

    script:
    """
    RepeatMasker -lib ${library} -xsmall ${genome} -pa ${task.cpus}

    mv *.masked "${meta.id}_sm.fa"
    """
}
