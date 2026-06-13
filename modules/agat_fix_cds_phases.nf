process FIX_METAEUK_CDS_PHASES {

    tag "${genome_name}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/agat:1.7.0--pl5321hdfd78af_0' :
        'quay.io/biocontainers/agat:1.7.0--pl5321hdfd78af_0' }"

    label 'process_light'

    input:
    tuple val(genome_name), path(metaeuk_gff), path(genome_fasta)

    output:
    tuple val(genome_name), path("*.metaeuk.phased.gff"), emit: gff

    script:
    """
    agat_sp_fix_cds_phases.pl \\
        --gff ${metaeuk_gff} \\
        -f ${genome_fasta} \\
        -o ${genome_name}.agat_phases.gff

    # AGAT duplicates MetaEuk feature lines including AGAT-annotated lines
    fix_metaeuk_cds_phases.py \\
        --metaeuk-gff ${metaeuk_gff} \\
        --agat-gff ${genome_name}.agat_phases.gff \\
        -o ${genome_name}.metaeuk.phased.gff
    """

    stub:
    """
    touch ${genome_name}.metaeuk.phased.gff
    """
}
