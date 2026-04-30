process REPEAT_MODELER {
    tag "${genome.baseName}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/repeatmodeler:2.0.7--pl5321hdfd78af_0':
        'quay.io/biocontainers/repeatmodeler:2.0.7--pl5321hdfd78af_0' }"


    input:
    tuple val(cluster), path(genome), path(proteins)

    output:
    tuple val(genome.baseName), path("*families.fa"), emit: repeat_families, optional: true
    tuple val(genome.baseName), path("*families.stk"), emit: repeat_aligment, optional: true
    tuple val(genome.baseName), path("*rmod.log"), emit: logile, optional: true

    script:
    """
    BuildDatabase -name ${genome.baseName} ${genome}

    RepeatModeler -database ${genome.baseName} -threads ${task.cpus} -LTRStruct
    """
}
