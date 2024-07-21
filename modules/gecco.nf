process GECCO_RUN {

    tag "${cluster_name}"
    
    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                String cluster_prefix = cluster_name.substring(0, cluster_name.length() - 2);
                return "species_catalogue/${cluster_prefix}/${cluster_name}/genome/${cluster_name}_gecco.gff"
            }
        },
        mode: 'copy',
        failOnError: true
    )

    container 'https://depot.galaxyproject.org/singularity/gecco:0.9.8--pyhdfd78af_0'

    input:
    tuple val(cluster_name), path(input)

    output:
    tuple val(cluster_name), path("*_gecco.gff"),  optional: true, emit: gecco_gff

    script:
    """
    gecco \\
        run \\
        -j $task.cpus \\
        -o ./ \\
        -g ${input}

    gecco convert clusters -i ./ --format gff
    
    if [ -e ${cluster_name}.clusters.gff ]
    then
        mv ${cluster_name}.clusters.gff ${cluster_name}_gecco.gff
    else
        echo "##gff-version 3" > ${cluster_name}_gecco.gff
    fi

    """
}
