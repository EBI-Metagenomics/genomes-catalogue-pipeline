/*
 * Prints Python-generated drep files (runs during catalogue update/reannotation only)
*/

process PRINT_DREP_FILES {

    publishDir "${params.outdir}/additional_data/intermediate_files/", mode: "copy"
    
    label 'process_light'
    
    input:
    path cdb
    path mdb
    path sdb
        
    output:
    path "drep_data_tables.tar.gz", emit: drep_data_tables_tarball
    
    script:
    """
    mkdir -p drep_data_tables && cp ${cdb} ${mdb} ${sdb} drep_data_tables/
    tar -czf drep_data_tables.tar.gz drep_data_tables
    """
    
    stub:
    """
    mkdir -p drep_data_tables && tar -czf drep_data_tables.tar.gz drep_data_tables
    """
}