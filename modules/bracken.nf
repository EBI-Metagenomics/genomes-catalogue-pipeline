process BRACKEN {

    container 'quay.io/biocontainers/bracken:2.6.2--py39hc16433a_0'

    input:
    val read_length
    path kraken_db

    output:

    script:
    """
    bracken-build -d ${kraken_db} \
    -t ${task.cpus} \
    -l ${read_length}
    """
}