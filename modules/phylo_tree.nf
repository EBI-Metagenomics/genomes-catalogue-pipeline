process PHYLO_TREE {

    // TODO: publishDir

    label 'process_light'

    cpus 1
    memory '1 GB'

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
