process COMBINE_CHUNKED_DREP {

    //publishDir(
    //    path: "${params.outdir}",
    //    saveAs: {
    //        filename -> {
    //            def output_file = file(filename);
    //            if ( output_file.name == "clusters_split.txt" ) {
    //                return "additional_data/intermediate_files/clusters_split.txt";
    //            }
    //           return null;
    //        }
    //    },
    //    mode: "copy",
    //    failOnError: true
    //)

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    tuple cdb_csv_list
    tuple sdb_csv_list
    file cdb_csv_second_run

    output:
    path "united_drep_output/Cdb.csv", emit: combined_cdb
    path "united_drep_output/Sdb.csv", emit: combined_sdb

    script:
    """
    unite_chunked_drep_outputs.py \
    --cdb-chunked cdb_csv_list \
    --sdb-chunked sdb_csv_list \
    --cdb-second-run cdb_csv_second_run \
    -o united_drep_output
    """

    // stub:
    // """
    // mkdir united_drep_output
    // touch united_drep_output/Cdb.csv
    // touch united_drep_output/Sdb.csv
    // """
}
