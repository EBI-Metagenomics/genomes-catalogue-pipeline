process IDENTIFY_SUPERKINGDOM {
   
    publishDir(
        path: "${params.outdir}",
        pattern: "superkingdoms.csv",
        saveAs: { "additional_data/intermediate_files/superkingdoms.csv" },
        mode: "copy",
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    path gtdb_summary_tsv

    output:
    path "superkingdoms.csv", emit: detected_superkingdoms

    script:
    """
    identify_superkingdom.py -i ${gtdb_summary_tsv} -o superkingdoms.csv
    """

    stub:
    """
    touch superkingdoms.csv
    """
}
