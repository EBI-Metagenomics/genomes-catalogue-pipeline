process COMBINE_CHUNKED_DREP {

    publishDir(
       path: "${params.outdir}/additional_data/intermediate_files/",
       mode: "copy",
       failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    path cdb_csv_list, stageAs: "cdb?.csv"
    path sdb_csv_list, stageAs: "sdb?.csv"
    path cdb_csv_second_run

    output:
    path "united_drep_output/Cdb.csv", emit: combined_cdb
    path "united_drep_output/Sdb.csv", emit: combined_sdb

    script:
    """
    unite_chunked_drep_outputs.py \
    --cdb-chunked cdb*.csv \
    --sdb-chunked sdb*.csv \
    --cdb-second-run ${cdb_csv_second_run} \
    -o united_drep_output
    """

    // stub:
    // """
    // mkdir united_drep_output
    // touch united_drep_output/Cdb.csv
    // touch united_drep_output/Sdb.csv
    // """
}
