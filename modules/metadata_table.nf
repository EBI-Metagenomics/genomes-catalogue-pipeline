process METADATA_TABLE {

    publishDir(
        "${params.outdir}/",
        pattern: "genomes-all_metadata.tsv",
        mode: "copy",
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    path genomes_fnas, stageAs: "genomes_dir/*"
    path extra_weights_tsv
    path check_results_tsv
    path rrna_out_results, stageAs: "rRNA_outs/*"
    path name_mapping_tsv
    path clusters_tsv
    path gtdb_summary_tsv
    val ftp_name
    val ftp_version
    file location_table
    file gunc_failed_txt

    output:
    path "genomes-all_metadata.tsv", emit: metadata_tsv

    script:
    def args = ""
    if (gunc_failed_txt != "EMPTY") {
        args = args + "--gunc-failed ${gunc_failed_txt}"
    }
    """
    create_metadata_table.py \
    --genomes-dir genomes_dir \
    --extra-weight-table ${extra_weights_tsv} \
    --checkm-results ${check_results_tsv} \
    --rna-results rRNA_outs \
    --naming-table ${name_mapping_tsv} \
    --clusters-table ${clusters_tsv} \
    --taxonomy ${gtdb_summary_tsv} \
    --ftp-name ${ftp_name} \
    --ftp-version ${ftp_version} \
    --location-table ${location_table} ${args} \
    --outfile genomes-all_metadata.tsv
    """

    // stub:
    // """
    // touch metadata_table.tsv
    // """
}
