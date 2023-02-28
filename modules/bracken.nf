process BRACKEN {

    container 'quay.io/biocontainers/bracken:2.8--py310h30d9df9_0'

    input:
    val read_length
    path kraken_db

    output:
    stdout

    script:
    """
    bracken-build -d ${kraken_db} \
    -t ${task.cpus} \
    -l ${read_length}
    """
}