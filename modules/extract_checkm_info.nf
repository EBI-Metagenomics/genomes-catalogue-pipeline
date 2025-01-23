process EXTRACT_CHECKM_INFO {
    
    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    label 'process_light'
    
    errorStrategy = 'terminate'
    
    input:
    path(previous_metadata_table)
    
    output:
    path("checkm_quality_previous_version.csv"), emit: quality_csv    
    
    script:
    """
    extract_checkm_from_metadata_table.py -i ${previous_metadata_table} -o checkm_quality_previous_version.csv
    
    """
    
    stub:
    """
    touch checkm_quality_previous_version.csv
    """

}