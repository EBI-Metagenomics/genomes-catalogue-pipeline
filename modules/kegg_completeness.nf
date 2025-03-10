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

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/kegg-pathways-completeness:1.3.0--pyhdfd78af_0':
        'biocontainers/kegg-pathways-completeness:1.3.0--pyhdfd78af_0' }"

    input:
    tuple val(cluster), file(eggnog_annotation_tsvs)

    output:
    tuple val(cluster), path("*_kegg_pathways.tsv"), emit: pathways

    script:
    """
    # Prepare input
    prep_pathway_completeness_input.py -e ${eggnog_annotation_tsvs} -o ${cluster}_kos.txt
    
    give_completeness \\
    -l ${cluster}_kos.txt \\
    -o ${cluster}
    
    mv ${cluster}/summary.kegg_pathways.tsv ${cluster}_kegg_pathways.tsv
    """

    stub:
    """
    touch ${cluster}_kegg_pathways.tsv
    """
}
