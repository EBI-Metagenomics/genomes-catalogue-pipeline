process FILTER_QS50 {

    publishDir(
        path: "${params.outdir}",
        pattern: "QC_failed_genomes.txt",
        saveAs: { "additional_data/intermediate_files/QC_failed_genomes.txt" },
        mode: "copy"
    )
    publishDir(
        path: "${params.outdir}",
        pattern: "filtered_genomes.csv",
        saveAs: { "additional_data/intermediate_files/filtered_genomes.csv" },
        mode: "copy"
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    path genomes
    path checkm_csv

    output:
    path "QC_failed_genomes.txt", emit: failed_genomes
    path "${genomes.baseName}_filtered", emit: filtered_genomes
    path "filtered_genomes.csv", emit: filtered_csv

    script:
    """
    filter_qs50.py -i ${genomes} -c ${checkm_csv} --filter
    """
}
