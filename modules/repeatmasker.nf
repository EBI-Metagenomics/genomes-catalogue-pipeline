process REPEAT_MASKER {
    tag "${genome.baseName}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/repeatmasker:4.2.3--pl5321hdfd78af_0' :
        'quay.io/biocontainers/repeatmasker:4.2.3--pl5321hdfd78af_0' }"


    input:
    val genome_name
    path genome, stageAs: "input/*"
    path proteins
    path library

    output:
    tuple val(genome_name), path("${genome.baseName}.fa"), emit: masked_genome

    script:
    """
    set -euo pipefail

    # Make HOME unique for this task; RepeatMasker will then use \$HOME/.RepeatMaskerCache
    export HOME="\$PWD/.home"
    mkdir -p "\$HOME"

    RepeatMasker -lib ${library} -xsmall ${genome} -pa ${task.cpus}

    mv "${genome}.masked" "${genome.baseName}.fa"
    """
}
