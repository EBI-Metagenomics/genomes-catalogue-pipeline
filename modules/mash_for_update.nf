process MASH_FOR_UPDATE {

    container 'quay.io/biocontainers/mash:2.3--hd3113c8_4'
    
    input:
    path previous_catalogue_location
    path new_genomes
    
    output:
    path("new_genomes_against_catalogue.out"), emit: update_mash_out
    
    script:
    """
    mash dist \
    -p ${task.cpus} \
    -d 0.05 \
    ${previous_catalogue_location}/ftp/all_genomes.msh \
    ${new_genomes.join( ' ' )} \
    > new_genomes_against_catalogue.out
    """

}
