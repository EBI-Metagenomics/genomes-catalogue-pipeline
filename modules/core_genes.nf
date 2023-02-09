
process CORE_GENES {

    publishDir "results/panaroo/${cluster_name}/", mode: 'copy'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    tuple val(cluster_name), file(panaroo_gen_preabs)

    output:
    tuple val(cluster_name), path('*.core_genes.txt'), emit: core_genes

    script:
    """
    get_core_genes.py \
    -i ${panaroo_gen_preabs} \
    -o ${cluster_name}.core_genes.txt
    """

    // stub:
    // """
    // touch ${cluster_name}.core_genes.txt
    // """
}
