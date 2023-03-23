process AMRFINDER_PLUS {

    tag "${cluster}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                def cluster_prefix = cluster.substring(0, 11);
                return "species_catalogue/${cluster_prefix}/${cluster}/genome/${cluster}_amrfinderplus.tsv";
            }
        },
        mode: "copy"
    )

    container 'quay.io/biocontainers/ncbi-amrfinderplus:3.11.4--h6e70893_0'

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
