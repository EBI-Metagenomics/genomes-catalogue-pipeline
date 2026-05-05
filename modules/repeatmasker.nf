process REPEAT_MASKER {
    tag "${genome_name}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/repeatmasker:4.2.3--pl5321hdfd78af_0' :
        'quay.io/biocontainers/repeatmasker:4.2.3--pl5321hdfd78af_0' }"


    input:
    tuple val(genome_name), path(genome, stageAs: "${genome_name}_before_masking.fa"), path(proteins)
    tuple val(genome_name), path(library)

    output:
    tuple val(genome_name), path("${genome_name}.fa"), emit: masked_genome

    script:
    """
    set -euo pipefail

    # Make HOME unique for this task; RepeatMasker will then use \$HOME/.RepeatMaskerCache
    export HOME="\$PWD/.home"
    mkdir -p "\$HOME"

    RepeatMasker -lib ${library} -xsmall ${genome_name}_before_masking.fa -pa ${task.cpus}

    mv *.masked "${genome_name}.fa"
    """
}
