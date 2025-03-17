process ANNOTATE_GFF {

    tag "${cluster}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                String cluster_rep_prefix = cluster.substring(0, cluster.length() - 2);
                return "species_catalogue/${cluster_rep_prefix}/${cluster}/genome/${gff.simpleName}_annotated.gff";
            }
        },
        mode: 'copy',
        failOnError: true
    )
    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                String cluster_rep_prefix = cluster.substring(0, cluster.length() - 2);
                return "all_genomes/${cluster_rep_prefix}/${cluster}/${gff.simpleName}.gff";
            }
        },
        mode: 'copy',
        failOnError: true
    )

    label 'process_light'

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    tuple val(cluster),
        file(gff),
        file(eggnog_annotations_tsv),
        file(ncrna_tsv),
        file(trna_gff),
        file(antismash_gff),
        file(dbcan_gff),
        file(ips_annotations_tsv)
    
    output:
    tuple val(cluster), path("*_annotated.gff"), emit: annotated_gff

    script:

    if ( antismash_gff ) {
        antismash_flag = "--antismash ${antismash_gff}"
    }
    if ( dbcan_gff ) {
        dbcan_flag = "--dbcan ${dbcan_gff}"
    }

    """
    
    annotate_euk_gff.py \
    -g ${gff} \
    -i ${ips_annotations_tsv} \
    -e ${eggnog_annotations_tsv} \
    -r ${ncrna_tsv} \
    -t ${trna_gff} \
    -o ${cluster}_annotated.gff \
    ${antismash_flag} ${dbcan_flag}
    """

    stub:
    """
    touch ${gff.simpleName}_annotated.gff
    """
}
