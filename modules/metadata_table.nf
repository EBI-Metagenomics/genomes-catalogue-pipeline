process METADATA_TABLE {

    publishDir "${params.outdir}/${params.catalogue_name}_metadata/", mode: 'copy'

    container 'quay.io/microbiome-informatics/genomes-pipeline.genomes-catalog-update:v1.1'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    path genomes_dir
    file extra_weights_tsv
    file check_results_tsv
    path rrna_out_results
    file name_mapping_tsv
    file clusters_tsv
    file gtdb_summary_tsv
    val ftp_name
    val ftp_version
    file geo_metadata
    file gunc_failed_tsv

    output:
    path 'metadata_table.tsv', emit: metadata_tsv

    script:
    """
    create_metadata_table.py \
    --genomes-dir ${genomes_dir} \
    --extra-weight-table ${extra_weights_tsv} \
    --checkm-results ${check_results_tsv} \
    --rna-results ${rrna_out_results} \
    --naming-table ${name_mapping_tsv} \
    --clusters-table ${clusters_tsv} \
    --taxonomy ${gtdb_summary_tsv} \
    --ftp-name ${ftp_name} \
    --ftp-version ${ftp_version} \
    --geo ${geo_metadata} \
    --gunc-failed ${gunc_failed_tsv} \
    --outfile genomes-all_metadata.tsv
    """

    // stub:
    // """
    // touch metadata_table.tsv
    // """
}
