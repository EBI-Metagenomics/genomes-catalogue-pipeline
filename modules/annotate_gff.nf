process ANNONTATE_GFF {

    publishDir "results/gff/${cluster}/", mode: 'copy'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    tuple val(cluster), file(gff), file(ips_annotations_tsv), file(eggnog_annotations_tsv), file(ncrna_tsv)

    output:
    tuple val(cluster), path("*_annotated.gff"), emit: annotated_gff

    script:
    """
    annotate_gff.py \
    -g ${gff} \
    -i ${ips_annotations_tsv} \
    -e ${eggnog_annotations_tsv} \
    -r ${ncrna_tsv}
    """

    // stub:
    // """
    // touch ${gff.simpleName}_annotated.gff
    // """
}
