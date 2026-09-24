process FILTER_QS50 {

    publishDir(
        path: "${params.outdir}/additional_data/intermediate_files",
        pattern: "QS50_failed_genomes.txt",
        saveAs: { "QS50_failed_genomes.txt" },
        mode: "copy"
    )
    publishDir(
        path: "${params.outdir}/additional_data/intermediate_files",
        pattern: "filtered_genomes.csv",
        saveAs: { "filtered_new_genomes.csv" },
        mode: "copy"
    )
    publishDir(
        path: "${params.outdir}/additional_data/intermediate_files",
        pattern: "QS50_failed_genomes_details.csv",
        saveAs: { "QS50_failed_genomes_details.csv" },
        mode: "copy"
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    path genomes
    path checkm_csv

    output:
    path "QS50_failed_genomes.txt", emit: failed_genomes
    path "${genomes.baseName}_filtered", emit: filtered_genomes
    path "filtered_genomes.csv", emit: filtered_csv
    path "QS50_failed_genomes_details.csv", emit: failed_genomes_details

    script:
    """
    filter_qs50.py -i ${genomes} -c ${checkm_csv} --filter \
    --details-csv QS50_failed_genomes_details.csv
    """
}
