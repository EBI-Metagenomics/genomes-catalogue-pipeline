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
    path new_species_split_file      
    
    output:
    path "assembly_stats_all_genomes.tsv", emit: assembly_stats_all_genomes
    path "extra_weight_table_all_genomes_filtered.tsv", emit: extra_weight_table_all_genomes
    path "update_clusters_split.txt", emit: updated_text_split
    path "update_renamed_genomes_name_mapping_filtered.tsv", emit: updated_genomes_name_mapping
    path "checkm_all_genomes.csv", emit: checkm_all_genomes
    path "update_cluster_rep_changes_report.tsv", emit: species_rep_replacement_report
        
    script:
    def new_strain_arg      = new_strains_file.name.startsWith('NO_FILE')        ? '' : "--new-strain-list ${new_strains_file}" 
    def repeat_strain_arg   = repeat_strains_file.name.startsWith('NO_FILE')     ? '' : "--repeat-strain-list ${repeat_strains_file}"
    def new_species_arg     = new_species_split_file.name.startsWith('NO_FILE')  ? '' : "--new-species-split-file ${new_species_split_file}"
    def checkm2_arg         = params.rerun_checkm2                   ? '--checkm2_switch' : ''

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
    
    # Place all new genomes into clusters and replace species reps as needed
    # Optional arguments based on file existence are defined above
    
    replace_species_representative.py \
    --cluster-split-file clusters_split_filtered.txt \
    --output-prefix update \
    --assembly-stats assembly_stats_all_genomes.tsv \
    --isolates extra_weight_table_all_genomes.tsv \
    --checkm checkm_all_genomes.csv \
    --remove-list ${remove_genomes} \
    ${new_strain_arg} \
    ${repeat_strain_arg} \
    ${new_species_arg} \
    ${checkm2_arg}
    
    # combine name mapping files
    if [ -s ${new_genomes_name_mapping} ]; then
        cat ${new_genomes_name_mapping} \
        ${previous_catalogue_location}/additional_data/intermediate_files/renamed_genomes_name_mapping.tsv \
        > update_renamed_genomes_name_mapping.tsv
    else
        cp ${previous_catalogue_location}/additional_data/intermediate_files/renamed_genomes_name_mapping.tsv \
        update_renamed_genomes_name_mapping.tsv
    fi
    
    # filter accessions from the remove list from outputs (note: if we use versioned MGYG accessions in the future, this 
    # code needs to be changed because it removes mentions of an accession in a line so if we are removing 
    # MGYG00001 but adding MGYG00001.1, it will get filtered out)
    
    # Filter extra_weight_table_all_genomes.tsv
    grep -vFf <(cut -f1 ${remove_genomes}) extra_weight_table_all_genomes.tsv \
    > extra_weight_table_all_genomes_filtered.tsv

    # Filter update_renamed_genomes_name_mapping.tsv
    grep -vFf <(cut -f1 ${remove_genomes}) update_renamed_genomes_name_mapping.tsv \
    > update_renamed_genomes_name_mapping_filtered.tsv
    """
}