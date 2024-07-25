process IDENTIFY_DOMAIN {
   
    publishDir(
        path: "${params.outdir}",
        pattern: "domains.csv",
        saveAs: { "additional_data/intermediate_files/domains.csv" },
        mode: "copy",
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    path gtdb_summary_tsv
    path cluster_splits

    output:
    path "domains.csv", emit: detected_domains

    script:
    """
    identify_domain.py -i ${gtdb_summary_tsv} -o domains.csv -c ${cluster_splits}
    """

    stub:
    """
    touch domains.csv
    """
}
