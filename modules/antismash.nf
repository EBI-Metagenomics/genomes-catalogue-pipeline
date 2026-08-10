process ANTISMASH {

    tag "${cluster_name}"

    container 'quay.io/nf-core/antismash:8.0.1--pyhdfd78af_0'
    
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