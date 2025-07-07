process ANTISMASH {

    tag "${cluster_name}"

    container 'quay.io/microbiome-informatics/antismash:7.1.0.1_2'
    
    label 'retry_twice'

    input:
    tuple val(cluster_name), path(gbk)
    path(antismash_db)

    output:
    tuple val(cluster_name), path("${cluster_name}_results/${cluster_name}.json"), emit: antismash_json

    script:
    """
    antismash \\
    -t bacteria \\
    -c ${task.cpus} \\
    --databases ${antismash_db} \\
    --output-basename ${cluster_name} \\
    --genefinding-tool none \\
    --output-dir ${cluster_name}_results \\
    ${gbk}
    """
}