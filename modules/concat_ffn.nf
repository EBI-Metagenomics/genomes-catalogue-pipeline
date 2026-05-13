process CONCAT_FFN {
    tag "${cluster_name}"
    label 'process_single'

    input:
    tuple val(meta), path(ffn_files)

    output:
    tuple val(meta), path("*.concat.ffn"), emit: ffn

    script:
    def prefix = task.ext.prefix ?: "${cluster_name}"
    """
    cat ${ffn_files.join(' ')} > ${prefix}.concat.ffn
    """
}

