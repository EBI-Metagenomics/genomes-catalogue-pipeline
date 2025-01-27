process GENE_CATALOGUE {

    publishDir "${params.outdir}/", mode: 'copy', failOnError: true

    container 'quay.io/biocontainers/seqtk:1.3--h7132678_4'

    input:
    path cluster_reps_ffn
    path mmseqs_100_cluster_tsv

    output:
    path "gene_catalogue", emit: gene_catalogue

    script:
    """
    cut -f1 ${mmseqs_100_cluster_tsv} | sort -u > rep_list.txt

    mkdir gene_catalogue

    cp ${mmseqs_100_cluster_tsv} gene_catalogue/clusters.tsv

    # Make the catalogue #
    seqtk subseq \
    ${cluster_reps_ffn} \
    rep_list.txt > gene_catalogue/gene_catalogue-100.ffn
    """
}
