process QS50_FILTER_PREVIOUS_VERSION {

    publishDir(
        "${params.outdir}/additional_data/update_execution_reports/",
        pattern: "*previous*",
        mode: "copy",
        failOnError: true
    )
    
    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'
    
    input:
    path previous_version_quality_file
    path remove_genomes
    path mgyg_genomes_folder
    
    output:
    path "qs50_failed_previous_catalogue_version.txt", emit: previous_version_qs50_failed
    path "qs50_passed_previous_catalogue_version.csv", emit: previous_version_qs50_qs50_passed
    path "remove_list_updated.tsv", emit: remove_list_mgyg_updated
    
    script:
    """
    filter_qs50.py \
    -i ${mgyg_genomes_folder} \
    -c ${previous_version_quality_file} \
    -o qs50_failed_previous_catalogue_version.txt \
    --output-csv qs50_passed_previous_catalogue_version.csv 
    
    # combine existing remove pile and genomes that failed QS50 
    add_genomes_to_remove_list.py \
    -r ${remove_genomes} \
    -a qs50_failed_previous_catalogue_version.txt \
    -m "Failed QS50 with CheckM2" \
    -o remove_list_updated.tsv

    """

}