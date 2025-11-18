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
    mash dist \
    -p ${task.cpus} \
    -d 0.05 \
    ${previous_catalogue_location}/ftp/all_genomes.msh \
    ${new_genomes}/*fa \
    > new_genomes_against_catalogue.out
    """

}
