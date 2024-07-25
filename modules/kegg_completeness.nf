process KEGG_COMPLETENESS {

    label 'process_light'

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def cluster_prefix = cluster.substring(0, cluster.length() - 2);
                return "species_catalogue/${cluster_prefix}/${cluster}/genome/${filename}";
            }
        },
        mode: "copy",
        failOnError: true
    )

    container 'https://depot.galaxyproject.org/singularity/kegg-pathways-completeness:1.0.5--pyhdfd78af_0'

    input:
    tuple val(cluster), file(eggnog_annotation_tsvs)

    output:
    tuple val(cluster), path("*summary.kegg_pathways.tsv"), emit: pathways

    script:
    """
    # Prepare input
    prep_pathway_completeness_input.py -e ${eggnog_annotation_tsvs} -o ${cluster}_kos.txt
    
    give_pathways \\
    -l ${cluster}_kos.txt \\
    -o ${cluster}
    """

    stub:
    """
    touch ${cluster}.kegg.summary.kegg_pathways.tsv

    """
}
