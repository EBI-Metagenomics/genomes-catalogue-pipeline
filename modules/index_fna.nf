process INDEX_FNA {

    tag "${cluster_name}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                String genome_name = fasta.baseName;
                String cluster_prefix = cluster_name.substring(0, 11);
                def is_rep = genome_name == cluster_name;
                if ( is_rep ) {
                    return "species_catalogue/${cluster_prefix}/${genome_name}/genome/${filename}";
                }
            }
        },
        mode: 'copy'
    )

    container "quay.io/biocontainers/samtools:1.9--h10a08f8_12"

    label 'process_light'

    input:
    tuple val(cluster_name), file(fasta)

    output:
    path '*.fai', emit: fasta_index

    script:
    """
    samtools faidx ${fasta}
    """

    stub:
    """
    touch ${fasta.simpleName}.fai
    """
}
