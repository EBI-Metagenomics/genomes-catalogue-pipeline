process RUN_CLUSTER_UPDATE {

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    input:
    path previous_catalogue_location
    path remove_genomes
    path previous_version_quality_file
    path previous_version_assembly_stats
    path new_data_checkm
    path new_genome_stats
    path extra_weight_table_new_genomes
    path new_genomes_name_mapping
    path new_strains_file
    path repeat_strains_file
    path new_species_split_file, stageAs: "new_species_cluster_split.txt"      
    
    output:
    path "assembly_stats_all_genomes.tsv", emit: assembly_stats_all_genomes
    path "extra_weight_table_all_genomes.tsv", emit: extra_weight_table_all_genomes
    path "update_clusters_split.txt", emit: updated_text_split
    path "update_renamed_genomes_name_mapping.tsv", emit: updated_genomes_name_mapping
    path "checkm_all_genomes.csv", emit: checkm_all_genomes
    path "update_cluster_rep_changes_report.tsv", emit: species_rep_replacement_report
        
    script:
    """
    # filter out singletons from the previous version's cluster split file if they weren't
    # in the metadata table (meaning they were filtered out by GUNC)
    
    filter_cluster_split.py \
    -i ${previous_catalogue_location}/additional_data/intermediate_files/clusters_split.txt \
    -o clusters_split_filtered.txt \
    -m ${previous_catalogue_location}/ftp/genomes-all_metadata.tsv
    
    gather_qc_stats_for_update.py \
    --stats-file-new ${new_genome_stats} \
    --stats-file-prev-version ${previous_version_assembly_stats} \
    --checkm-previous-version ${previous_version_quality_file} \
    --checkm-new-genomes ${new_data_checkm} \
    --extra-weight-new-genomes ${extra_weight_table_new_genomes} \
    --previous-version-path ${previous_catalogue_location} \
    --outfile-stats assembly_stats_all_genomes.tsv \
    --outfile-extra-weight extra_weight_table_all_genomes.tsv \
    --outfile-checkm checkm_all_genomes.csv
    
    # place all new genomes into clusters and replace species reps as needed
    replace_species_representative.py \
    --cluster-split-file clusters_split_filtered.txt \
    --new-strain-list ${new_strains_file} \
    --repeat-strain-list ${repeat_strains_file} \
    --output-prefix update \
    --assembly-stats assembly_stats_all_genomes.tsv \
    --isolates extra_weight_table_all_genomes.tsv \
    --checkm checkm_all_genomes.csv \
    --remove-list ${remove_genomes} \
    --new-species-split-file new_species_cluster_split.txt
    
    # combine name mapping files
    if [ -s ${new_genomes_name_mapping} ]; then
        cat ${new_genomes_name_mapping} \
        ${previous_catalogue_location}/additional_data/intermediate_files/renamed_genomes_name_mapping.tsv \
        > update_renamed_genomes_name_mapping.tsv
    else
        cp ${previous_catalogue_location}/additional_data/intermediate_files/renamed_genomes_name_mapping.tsv \
        update_renamed_genomes_name_mapping.tsv
    fi
    """
}