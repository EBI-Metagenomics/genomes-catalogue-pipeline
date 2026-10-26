process RECONCILE_METAEUK_PHASES {

    tag "${genome_name}"

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    tuple val(genome_name), path(metaeuk_gff), path(agat_phases_gff)

    output:
    tuple val(genome_name), path("*.metaeuk.phased.gff"), emit: gff

    script:
    """
    fix_metaeuk_cds_phases.py \\
        --metaeuk-gff ${metaeuk_gff} \\
        --agat-gff ${agat_phases_gff} \\
        -o ${genome_name}.metaeuk.phased.gff
    """

    stub:
    """
    touch ${genome_name}.metaeuk.phased.gff
    """
}
