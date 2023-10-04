process SPLIT_DREP_LARGE {

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                if ( output_file.name == "clusters_split.txt" ) {
                    return "additional_data/intermediate_files/clusters_split.txt";
                }
                return null;
            }
        },
        mode: "copy",
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    file cdb_csv
    file sdb_csv

    output:
    path "split_output/clusters_split.txt", emit: text_split

    script:
    """
    split_drep.py --cdb ${cdb_csv} --sdb ${sdb_csv} -o split_output
    """

    // stub:
    // """
    // mkdir -p split_output
    // touch split_output/clusters_split.txt
    // """
}
