
process CORE_GENES {

    tag "${cluster_name}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                String cluster_rep_prefix = cluster_name.substring(0, 11);
                return "species_catalogue/${cluster_rep_prefix}/${cluster_name}/pan-genome/core_genes.txt"
            }
        },
        mode: 'copy'
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.0'

    label 'process_light'

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
