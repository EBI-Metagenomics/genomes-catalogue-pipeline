process CGT {
    tag "${cluster_name}"
    label 'process_medium'

    publishDir(
        path: "${params.outdir}",
        saveAs: { filename ->
            def output_file = file(filename);
            def extension = output_file.getExtension();
            String cluster_prefix = cluster_name.substring(0, cluster_name.length() - 2);
            if ( output_file.name == "${cluster_name}_cgt.txt" ) {
                return "species_catalogue/${cluster_prefix}/${cluster_name}/pan-genome/pangenome_correction.txt";
            }
        },
        mode: 'copy',
        failOnError: true
    )

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/cgt:1.0.0--h4349ce8_0'
        : 'quay.io/biocontainers/cgt:1.0.0--h4349ce8_0'}"

    input:
    tuple val(cluster_name), path(checkm2), path(rtab)

    output:
    tuple val(cluster_name), path("*_cgt.txt") , emit: cgt

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${cluster_name}"
    """
    sed 's|[.][a-zA-Z]*,|,|' ${checkm2} > checkm2_clean.csv

    cgt_bacpop \\
        ${args} \\
        --completeness-column 2 \\
        --output-file ${prefix}_cgt.txt \\
        checkm2_clean.csv \\
        ${rtab}
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${cluster_name}"
    """
    echo ${args}

    touch ${prefix}_cgt.txt
    """
}

