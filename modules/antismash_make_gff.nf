process ANTISMASH_MAKE_GFF {

    tag "${cluster}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                String cluster_rep_prefix = cluster.substring(0, cluster.length() - 2);
                return "species_catalogue/${cluster_rep_prefix}/${cluster}/genome/${cluster}_antismash.gff";
            }
        },
        mode: 'copy',
        failOnError: true
    )

    label 'process_light'

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    tuple val(cluster), file(antismash_json)
    file(antismash_version)
    
    output:
    tuple val(cluster), path("*_antismash.gff"), emit: antismash_gff

    script:
    """
    version=\$(cat ${antismash_version})
    antismash_to_gff.py -r ${antismash_json} -o ${cluster}_antismash.gff -a \${version}
    """

    stub:
    """
    touch ${cluster}_antismash.gff
    """
}
