process CONVERT_REMOVE_LIST_TO_MGYG {

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    label 'process_light'
    
    errorStrategy = 'terminate'
    
    input:
    path(previous_catalogue_location)
    file(remove_list_file)
    
    output:
    path("remove_list_mgyg.txt"), emit: remove_list_mgyg 
    
    script:
    """
    convert_remove_list_to_mgyg.py -i ${previous_catalogue_location} -r ${remove_list_file} -o remove_list_mgyg.txt
    """
    
    stub:
    """
    touch remove_list_mgyg.txt
    """

}