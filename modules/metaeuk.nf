process METAEUK {

    tag "${genome_name}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/metaeuk:7.bba0d80--pl5321h6a68c12_0' :
        'quay.io/biocontainers/metaeuk:7.bba0d80--pl5321h6a68c12_0' }"

    input:
    tuple val(genome_name), path(masked_genome), path(protein_evidence)

    output:
    tuple val(genome_name), path("*.metaeuk.gff"), emit: gff
    tuple val(genome_name), path("*.metaeuk.faa"), emit: proteins

    script:
    """
    metaeuk easy-predict \\
        ${masked_genome} \\
        ${protein_evidence} \\
        ${genome_name}.metaeuk \\
        tmp_${genome_name}

    mv ${genome_name}.metaeuk.fas ${genome_name}.metaeuk.faa
    """

    stub:
    """
    touch ${genome_name}.metaeuk.gff ${genome_name}.metaeuk.faa
    """
}
