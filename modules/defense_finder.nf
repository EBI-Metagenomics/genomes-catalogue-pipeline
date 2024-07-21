process DEFENSE_FINDER {

    tag "${cluster_name}"

    container 'quay.io/biocontainers/defense-finder:1.2.0--pyhdfd78af_0'

    input:
    tuple val(cluster_name), path(faa), path(prokka_gff)
    path(defense_finder_db)

    output:
    path("defense_finder_output/${cluster_name}_defense_finder.gff"), emit: gff

    script:
    """
    defense-finder run \\
        -o defense_finder_output \\
        --models-dir ${defense_finder_db} \\
        ${faa}

    process_defensefinder_result.py \\
        -i defense_finder_output/ \\
        -p ${prokka_gff} \\
        -o defense_finder_output/${cluster_name}_defense_finder.gff -v 1.2.0

    """
}
