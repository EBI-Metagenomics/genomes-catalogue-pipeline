process PARSE_DOMAIN {
   
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
    # Generate a CSV file with genome accession in the first column and domains (Bacteria, Archaea, or Undefined 
    # in the second column)
    
    parse_domain.py -i ${gtdb_summary_tsv} -o domains.csv -c ${cluster_splits}

    """

    stub:
    """
    touch domains.csv
    """
}
