process BUSCO_PHYLOGENOMICS {
    tag "species tree"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/busco_phylogenomics:20240919--pyhdfd78af_0':
        'biocontainers/busco_phylogenomics:20240919--pyhdfd78af_0' }"

    input:
    val busco_folders_list

    output:
    tuple val(meta), path("${prefix}/gene_trees_single_copy/"), emit: gene_trees
    tuple val(meta), path("${prefix}/supermatrix/")           , emit: supermatrix
    path "versions.yml"                                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '20240919' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    mkdir -p species_rep_busco
    for folder in ${busco_folders_list}; do
        echo "copying \$folder busco results"
        cp -r "\$folder" species_rep_busco/
    done

    BUSCO_phylogenomics.py \\
        -i species_rep_busco \\
        -o species_tree \\
        -t $task.cpus \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco_phylogenomics: $VERSION
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '20240919' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    mkdir ${prefix}
    mkdir ${prefix}/gene_trees_single_copy
    mkdir ${prefix}/supermatrix

    touch ${prefix}/gene_trees_single_copy/ALL.tree
    touch ${prefix}/supermatrix/SUPERMATRIX.fasta
    touch ${prefix}/supermatrix/SUPERMATRIX.partitions.nex
    touch ${prefix}/supermatrix/SUPERMATRIX.phylip

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco_phylogenomics: $VERSION
    END_VERSIONS
    """
}