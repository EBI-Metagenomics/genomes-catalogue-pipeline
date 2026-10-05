process GENERATE_ITOL_FILES {

    publishDir "${params.outdir}/phylogenies", mode: 'copy', failOnError: true, pattern: "*.txt"

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    path summary_tsv
    path metadata_table
    val(taxa_level)
    val(domain)

    output:
    path "*.txt", emit: itol_files

    script:
    def metadata_arg = metadata_table ? "--metadata ${metadata_table}" : ""
    """
    itol-format-generation.py \\
      --input ${summary_tsv} \\
      --taxa ${taxa_level} \\
      --domain ${domain} \\
      ${metadata_arg}
    """

    stub:
    """
    touch itol_gtdb-layer_empty.txt
    touch itol_gtdb-legend_empty.txt
    touch cluster_size_bac.txt
    """
}
