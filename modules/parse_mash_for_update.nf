process PARSE_MASH_FOR_UPDATE {

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    input:
    path new_genomes
    path mash_results
    path previous_catalogue_location
    
    output:
    path("mash_parse_results/New_species"), emit: new_species_folder
    path("mash_parse_results/new_strains.tsv"), emit: new_strains_file
    path("mash_parse_results/repeat_strains.tsv"), emit: repeat_strains_file
    
    script:
    """
    parse_mash.py \
    --mash ${mash_results} \
    --outfolder mash_parse_results \
    --input-folder ${new_genomes} \
    --metadata-table ${previous_catalogue_location}/ftp/genomes-all_metadata.tsv
    """
    
}