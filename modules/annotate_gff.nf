process ANNONTATE_GFF {

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                String cluster_rep_prefix = cluster.substring(0, 11);
                return "species_catalogue/${cluster_rep_prefix}/${cluster}/genome/${gff.simpleName}.gff";
            }
        },
        mode: 'copy'
    )
    
    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    tuple val(cluster), path(gff), path(ips_annotations_tsv), path(eggnog_annotations_tsv), path(sanntis_annotations_gff), path(ncrna_tsv)

    output:
    tuple val(cluster), path("*_annotated.gff"), emit: annotated_gff

    script:
    def sanntis_flag = ""
    if (sanntis_annotations_gff) {
        sanntis_flag = "-s ${sanntis_annotations_gff} "
    }
    """
    annotate_gff.py \
    -g ${gff} \
    -i ${ips_annotations_tsv} \
    -e ${eggnog_annotations_tsv} \
    -r ${ncrna_tsv} \
    ${sanntis_flag}
    """

    stub:
    """
    touch ${gff.simpleName}_annotated.gff
    """
}
