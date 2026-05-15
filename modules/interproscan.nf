/*
 * Interproscan
*/
process IPS {
    label 'retry_twice'
    label 'ips'

    container 'quay.io/microbiome-informatics/interproscan:5.77-108.0'

    containerOptions {
        def containerArgs = []
        def mountArg = (workflow.containerEngine == 'singularity') ? "--bind" : "--volume"

        containerArgs << "${mountArg} ${task.workDir}/${interproscan_db}/data:/opt/interproscan/data"

        if ( params.interpro_licensed_software ) {
            def licensedSoftwarePath = "${task.workDir}/${interproscan_db}/licensed"
            containerArgs << "${mountArg} ${licensedSoftwarePath}:/opt/interproscan/licensed"
            // This override is needed otherwise it fails because this path seems to be hardcoded in the container
            containerArgs << "${mountArg} ${licensedSoftwarePath}/signalp:/usr/opt/www/pub/CBS/services/SignalP-4.1/signalp-4.1"
        }

        return containerArgs.join(' ')
    }

    input:
    tuple val(meta), path(faa_fasta)
    path interproscan_db

    output:
    tuple val(meta), path('*.IPS.tsv'), emit: ips_annotations

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Set the max memory for the JVM
    export JAVA_OPTS="-Xmx${task.memory.toGiga()}G"

    # -dp (disable precalculation) is on so no online dependency
    interproscan.sh \\
        -cpu $task.cpus \\
        -dp \\
        ${args} \\
        -f TSV \\
        --input ${faa_fasta} \\
        -o ${prefix}.IPS.tsv

    """
    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}

    touch ${prefix}.IPS.tsv
    """

}
