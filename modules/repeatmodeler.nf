process REPEAT_MODELER {
    tag "${genome.baseName}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://dfam/tetools:latest' :
        'dfam/tettools:latest' }"


    input:
    tuple val(cluster), path(genome), path(proteins)

    output:
    tuple val(genome.baseName), path("*families.fa"), emit: repeat_families
    tuple val(genome.baseName), path("*families.stk"), emit: repeat_aligment
    tuple val(genome.baseName), path("*rmod.log"), emit: logile

    script:
    """
    BuildDatabase -name ${genome.baseName} ${genome}

    RepeatModeler -database ${genome.baseName} -threads ${task.cpus} -LTRStruct
    """
}
