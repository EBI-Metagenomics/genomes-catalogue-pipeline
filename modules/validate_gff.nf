
// TODO: this module is not in used ATM

process VALIDATE_GFF {

    publishDir(
        path: "{params.outdir}/additional_data/intermediary_files/gff_validation",
        mode: 'copy',
        failOnError: true
    )

    label 'ignore_errors'

    container 'quay.io/biocontainers/genometools-genometools:1.6.2--py310he7ef181_3'

    input:
    file gff

    output:
    path "*.validation"

    script:
    """
    gt gff3validator $gff > ${gff}.validation
    """
}
