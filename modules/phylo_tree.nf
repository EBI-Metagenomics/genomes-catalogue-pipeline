process PHYLO_TREE {

    publishDir "${params.outdir}/", mode: 'copy', failOnError: true

    label 'process_light'

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    file gtdb_taxonomy_tsv

    output:
    path 'phylo_tree.json', emit: phylo_tree

    script:
    """
    phylo_tree_generator.py --table ${gtdb_taxonomy_tsv} --out phylo_tree.json
    """

    // stub:
    // """
    // touch phylo_tree.json
    // """
}
