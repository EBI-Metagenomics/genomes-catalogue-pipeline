process PSAURON {

    tag "${genome_name}"

    publishDir(
        path: "${params.outdir}/additional_data/intermediate_files/psauron",
        pattern: "*.psauron.csv",
        mode: 'copy',
        failOnError: true
    )

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/psauron:1.1.0--pyhdfd78af_0' :
        'quay.io/biocontainers/psauron:1.1.0--pyhdfd78af_0' }"

    label 'process_light'

    input:
    // merged_gff is staged in a subdir so the output GFF can reuse the same name (${genome_name}.gff)
    tuple val(genome_name), path(merged_faa), path(merged_gff, stageAs: "input/*")

    output:
    tuple val(genome_name), path("*.psauron.csv"), path("*.gff"), emit: psauron

    script:
    """
    psauron \\
        -i ${merged_faa} \\
        -o ${genome_name}.psauron.csv \\
        -p

    add_psauron_score.py \\
        -i ${merged_gff} \\
        -p ${genome_name}.psauron.csv \\
        -o ${genome_name}.gff
    """

    stub:
    """
    touch ${genome_name}.psauron.csv ${genome_name}.gff
    """
}
