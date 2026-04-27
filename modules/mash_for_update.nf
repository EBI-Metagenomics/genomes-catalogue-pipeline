process MASH_FOR_UPDATE {

    publishDir(
        "${params.outdir}/additional_data/update_execution_reports/",
        mode: 'copy',
        failOnError: true
    )
    
    container 'quay.io/biocontainers/mash:2.3--hb105d93_10'
    
    input:
    path previous_catalogue_location
    path new_genomes
    
    output:
    path("mash_new_genomes_against_catalogue.out"), emit: update_mash_out
    
    script:
    """
    echo "Generate list"
    find ${new_genomes}/ -name "*.fa" > list.txt
    
    echo "mash sketch new genomes"
    mash sketch \
    -p ${task.cpus} \
    -l list.txt \
    -o new_genomes.msh
    
    echo "mash dist"
    mash dist \
    -p ${task.cpus} \
    -d 0.2 \
    ${previous_catalogue_location}/ftp/all_genomes.msh \
    new_genomes.msh \
    > mash_new_genomes_against_catalogue.out
    """

}
