process RUN_CLUSTER_UPDATE {

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    input:
        previous_catalogue_location
        remove_genomes
        previous_version_quality_file
        previous_version_assembly_stats
        new_data_checkm
        new_genome_stats
        extra_weight_table_new_genomes
    output:
        path "assembly_stats_all_genomes.tsv", emit: assembly_stats_all_genomes
    script:
    """
    gather_qc_stats_for_update.py \
    --stats-file-new ${new_genome_stats} \
    --stats-file-prev-version ${previous_version_assembly_stats} \
    --checkm-previous-version ${previous_version_quality_file} \
    --checkm-new-genomes ${new_data_checkm} \
    --extra-weight-new-genomes ${extra_weight_table_new_genomes} \
    --previous-version-path ${previous_catalogue_location} \
    --outfile-stats assembly_stats_all_genomes.tsv \
    --outfile-extra-weight extra_weight_table_all_genomes.tsv
    """
}