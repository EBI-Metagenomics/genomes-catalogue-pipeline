process EXTRACT_METADATA_FROM_TABLE {
    
    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    label 'process_light'
    
    errorStrategy = 'terminate'
    
    input:
    path(previous_metadata_table)
    
    output:
    path("previous_version_checkm_quality.csv"), emit: quality_csv // contains completeness and contamination    
    path("previous_version_assembly_stats.tsv"), emit: assembly_stats_tsv // contains length, N50, GC content   
    
    script:
    """
    extract_info_from_metadata_table.py -i ${previous_metadata_table} -o previous_version
    
    """
    
    stub:
    """
    touch previous_version_checkm_quality.csv
    touch previous_version_assembly_stats.tsv
    """

}