process CHECK_CATALOGUE_STRUCTURE {
    
    publishDir(
        "${params.outdir}/additional_data/intermediate_files/",
        pattern: "PREVIOUS_CATALOGUE_STRUCTURE*.txt",
        mode: "copy",
        failOnError: true
    )
    
    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    label 'process_light'
    
    errorStrategy = 'terminate'
    
    input:
    path(previous_catalogue_location)
    
    output:
    file("PREVIOUS_CATALOGUE_STRUCTURE*.txt")    
    
    script:
    """
    check_catalogue_structure.py -i ${previous_catalogue_location}
    
    # Check if error file exists
    if [ ! -f PREVIOUS_CATALOGUE_STRUCTURE_OK.txt ]; then
        echo "Error: there are missing files or folders in the catalogue to be updated. Fix the errors listed in PREVIOUS_CATALOGUE_STRUCTURE_ERRORS.txt and restart the pipeline. Workflow terminating." >&2
        exit 1
    fi
    """
    
    stub:
    """
    touch PREVIOUS_CATALOGUE_STRUCTURE_OK.txt
    """

}