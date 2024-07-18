process GENERATE_COMBINED_QC_REPORT {
   
    publishDir(
        path: "${params.outdir}",
        pattern: "combined_removed_genomes_report.txt",
        saveAs: { "additional_data/combined_removed_genomes_report.txt" },
        mode: "copy",
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    path qc_filtered
    path gunc_failed
    path gtdbtk_failed

    output:
    path "combined_removed_genomes_report.txt", emit: combined_qc_report

    script:
    """
    generate_combined_qc_report.py \
    --qc ${qc_filtered} \
    --gunc ${gunc_failed} \
    --gtdb ${gtdbtk_failed} \
    -o combined_removed_genomes_report.txt
    """

    stub:
    """
    touch combined_qc_report.txt
    """
}
