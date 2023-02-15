
process CORE_GENES {

    tag "${cluster_name}"

    publishDir(
        "{params.outdir}/${catalogue_name}_metadata/${cluster_name}/pan-genome",
        saveAs: { filename -> "core_genes.txt" }
        mode: 'copy'
    )

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
