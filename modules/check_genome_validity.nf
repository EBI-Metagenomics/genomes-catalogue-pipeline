process CHECK_GENOME_VALIDITY {

    //publishDir(
    //    "${params.outdir}/additional_data/intermediate_files/",
    //    pattern: "GENOME_CHECK_*",
    //    mode: "copy",
    //    failOnError: true
    //)
    
    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    label 'process_light'
    
    errorStrategy = 'terminate'
    
    input:
    path(previous_catalogue_location)
    file(remove_list_file)
    
    output:
    file("GENOME_CHECK_*")    
    
    script:
    """
    check_sample_and_mag_validity.py -i ${previous_catalogue_location} -r ${remove_list_file}
    # Check if any genomes failed checks
    if [ -f GENOME_CHECK_FAILED_ACCESSIONS ]; then
        echo "Error: some genomes can no longer be found in ENA. Check that this is correct. If so, add them to the remove list and restart the pipeline." >&2
        exit 1
    fi
    """
    
    stub:
    """
    touch GENOME_CHECK_ALL_GENOMES_OK
    """

}