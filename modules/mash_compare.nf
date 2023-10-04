process MASH_COMPARE {

    container 'quay.io/biocontainers/mash:2.3--hd3113c8_4 '
    
    // THIS NEEDS A LOT OF WORK. OUTPUT FILE NEEDS TO BE NAMED WITH THE CLUSTER NAME
    // the cluster name is somewhere in many_genomes_fnas
    input:
    path many_genomes_fnas

    output:
    path "CLUSTERNAME_mash.tsv", emit: mash_split
    
    // the join part below is almost definitely wrong

    script:
    """
    mash sketch -o cluster.msh ${many_genomes_fnas.join( ' ' )}
    mash dist cluster.msh cluster.msh > "CLUSTERNAME"_mash.tsv
    """
}
