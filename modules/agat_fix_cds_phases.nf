process FIX_METAEUK_CDS_PHASES {

    tag "${genome_name}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/agat:1.7.0--pl5321hdfd78af_0' :
        'quay.io/biocontainers/agat:1.7.0--pl5321hdfd78af_0' }"

    label 'process_light'

    input:
    tuple val(genome_name), path(metaeuk_gff), path(genome_fasta)

    output:
    tuple val(genome_name), path("*.agat_phases.gff"), emit: gff

    script:
    """
    agat_sp_fix_cds_phases.pl \\
        --gff ${metaeuk_gff} \\
        --fa ${genome_fasta} \\
        -o ${genome_name}.agat_phases.gff
    """

    stub:
    """
    touch ${genome_name}.agat_phases.gff
    """
}
