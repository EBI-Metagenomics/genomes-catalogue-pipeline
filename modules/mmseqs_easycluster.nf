process MMSEQS_EASYCLUSTER {
    tag "${cluster_name}"
    label 'process_medium'

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/mmseqs2:18.8cc5c--hd6d6fdc_0'
        : 'quay.io/biocontainers/mmseqs2:18.8cc5c--hd6d6fdc_0'}"

    input:
    tuple val(cluster_name), path(sequence)

    output:
    tuple val(cluster_name), path("*rep_seq.fasta") , emit: representatives
    tuple val(cluster_name), path("*all_seqs.fasta"), emit: fasta
    tuple val(cluster_name), path("*.tsv")          , emit: tsv

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${cluster_name}"
    """
    mmseqs \\
        easy-cluster \\
        ${sequence} \\
        ${prefix} \\
        tmp1 \\
        ${args} \\
        --threads ${task.cpus}

    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${cluster_name}"
    """
    echo ${args}

    touch ${prefix}.tsv
    touch ${prefix}_rep_seq.fasta
    touch ${prefix}_all_seqs.fasta
    """
}
