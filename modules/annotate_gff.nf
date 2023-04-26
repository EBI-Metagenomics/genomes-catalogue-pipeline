process ANNONTATE_GFF {

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
                return "all_genomes/${cluster_rep_prefix}/${gff.simpleName}.gff";
            }
        },
        mode: 'copy',
        failOnError: true
    )

    label 'process_light'

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    tuple val(cluster), path(gff), path(ips_annotations_tsv), path(eggnog_annotations_tsv), path(sanntis_annotations_gff), path(ncrna_tsv), path(crisprcas_hq_gff), path(amrfinder_tsv)

    output:
    tuple val(cluster), path("*_annotated.gff"), emit: annotated_gff

    script:
    def sanntis_flag = "";
    def crisprcas_flag = "";
    def amrfinder_flag = "";
    if ( sanntis_annotations_gff ) {
        sanntis_flag = "-s ${sanntis_annotations_gff} ";
    }
    if ( crisprcas_hq_gff ) {
        crisprcas_flag = "-c ${crisprcas_hq_gff} ";
    }
    if ( amrfinder_tsv ) {
        amrfinder_flag = "-a ${amrfinder_tsv}"
    }
    """
    annotate_gff.py \
    -g ${gff} \
    -i ${ips_annotations_tsv} \
    -e ${eggnog_annotations_tsv} \
    -r ${ncrna_tsv} \
    ${crisprcas_flag} ${sanntis_flag} ${amrfinder_flag}
    """

    stub:
    """
    touch ${gff.simpleName}_annotated.gff
    """
}
