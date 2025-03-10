process REPEAT_MODELER {
    tag "$meta.id"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://dfam/tetools:latest' :
        'dfam/tettools:latest' }"


    input:
    tuple val(meta), path(genome)

    output:
    tuple val(meta), path("*families.fa"), emit: repeat_families
    tuple val(meta), path("*families.stk"), emit: repeat_aligment
    tuple val(meta), path("*rmod.log"), emit: logile

    script:
    """
    BuildDatabase -name ${meta.id} ${genome}

    RepeatModeler -database ${meta.id} -threads ${task.cpus} -LTRStruct
    """
}
