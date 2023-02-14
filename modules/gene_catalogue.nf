process GENE_CATALOGUE {

    publishDir "${params.outdir}/gene_catalogue", mode: 'copy'

    container 'quay.io/biocontainers/seqtk:1.3--h7132678_4'

    input:
    path cluster_reps_ffn
    path mmseqs_1_0_outdir

    output:
    path 'gene_catalogue', emit: gene_catalogue

    script:
    """
    [ -f "${mmseqs_1_0_outdir}/mmseqs_1.0_outdir/mmseqs_cluster.tsv" ] && echo 1 || echo 0

    cut -f1 ${mmseqs_1_0_outdir}/mmseqs_1.0_outdir/mmseqs_cluster.tsv | sort -u > rep_list.txt

    mkdir gene_catalogue

    cp ${mmseqs_1_0_outdir}/mmseqs_1.0_outdir/mmseqs_cluster.tsv gene_catalogue/clusters.tsv

    # Make the catalogue #
    seqtk subseq \
    ${cluster_reps_ffn} \
    rep_list.txt > gene_catalogue/gene_catalogue-100.ffn
    """
}