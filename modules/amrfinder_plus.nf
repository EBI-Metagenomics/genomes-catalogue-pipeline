process AMRFINDER_PLUS {

    tag "${cluster}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                def cluster_prefix = cluster.substring(0, cluster.length() - 2);
                return "species_catalogue/${cluster_prefix}/${cluster}/genome/${cluster}_amrfinderplus.tsv";
            }
        },
        mode: "copy",
        failOnError: true
    )

    container 'quay.io/biocontainers/ncbi-amrfinderplus:3.12.8--h283d18e_0'
    
    errorStrategy = { task.attempt <= 2 ? 'retry' : 'finish' }

    input:
    tuple val(cluster), path(fna), path(faa), path(gff)

    output:
    tuple val(cluster), path("${fna.baseName}_amrfinderplus.tsv"), emit: amrfinder_tsv

    script:
    """
    amrfinder --plus \
    -n ${fna} \
    -p ${faa} \
    -g ${gff} \
    -d ${params.amrfinder_plus_db} \
    -a prokka \
    --output ${cluster}_amrfinderplus.tsv \
    --threads ${task.cpus}
    """
}
