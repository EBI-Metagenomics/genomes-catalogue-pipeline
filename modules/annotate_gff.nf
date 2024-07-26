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
        file(crisprcas_hq_gff),
        file(amrfinder_tsv),
        file(antismash_gff),
        file(gecco_gff),
        file(dbcan_gff),
        file(df_gff),
        file(ips_annotations_tsv),
        file(sanntis_annotations_gff),
    
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
    if ( antismash_gff ) {
        antismash_flag = "--antismash ${antismash_gff}"
    }
    if ( gecco_gff ) {
        gecco_flag = "--gecco ${gecco_gff}"
    }
    if ( dbcan_gff ) {
        dbcan_flag = "--dbcan ${dbcan_gff}"
    }
    if ( df_gff ) {
        df_flag = "--defense-finder ${df_gff}"
    }
    """
    annotate_gff.py \
    -g ${gff} \

    -e ${eggnog_annotations_tsv} \
    -r ${ncrna_tsv} \
    ${crisprcas_flag} ${sanntis_flag} ${amrfinder_flag}
    
    annotate_gff.py \
    -g ${gff} \
    -i ${ips_annotations_tsv} \
    -e ${eggnog_annotations_tsv} \
    -r ${ncrna_tsv} \
    -t ${trna_gff} \
    -o ${cluster}_annotated.gff \
    ${crisprcas_flag} ${sanntis_flag} ${amrfinder_flag} \
    ${antismash_flag} ${gecco_flag} ${dbcan_flag} ${df_flag}
    """

    stub:
    """
    touch ${gff.simpleName}_annotated.gff
    """
}
