process CONCAT_FFN {
    tag "${cluster_name}"
    label 'process_single'

    input:
    tuple val(cluster_name), path(ffn_files, stageAs: 'input/*')

    output:
    tuple val(cluster_name), path("*.concat.ffn"), emit: ffn

    script:
    def prefix = task.ext.prefix ?: "${cluster_name}"
    """
    concat_ffn.py --input-dir input/ --output ${prefix}.concat.ffn
    """
}

