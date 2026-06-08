process DEDUP_GFF {

    tag "${genome_name}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/agat:1.7.0--pl5321hdfd78af_0' :
        'quay.io/biocontainers/agat:1.7.0--pl5321hdfd78af_0' }"

    label 'process_light'

    input:
    tuple val(genome_name), path(gff)

    output:
    tuple val(genome_name), path("*.dedup.gff"), emit: dedup_gff

    script:
    """
    agat_sp_fix_features_locations_duplicated.pl \\
        --gff ${gff} \\
        -o ${genome_name}.dedup.gff
    """

    stub:
    """
    touch ${genome_name}.dedup.gff
    """
}
