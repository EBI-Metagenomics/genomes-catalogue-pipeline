/* TODO: improve description
 * Phylogenetic tree generation and metadata colleciton.
*/

include { METADATA_TABLE } from '../modules/metadata_table'
include { PHYLO_TREE } from '../modules/phylo_tree'

process PREPARE_LOCATION_INPUT {
    
    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    input:
    file gunc_failed_txt
    path name_mapping_tsv
    
    output:
    path "accession_list.txt", emit: locations_input_tsv
    
    script:
    """
    prepare_locations_input.py \
    --gunc-failed ${gunc_failed_txt} \
    --name-mapping ${name_mapping_tsv} \
    --output accession_list.txt
    """
}

process FETCH_LOCATIONS {

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    errorStrategy = { task.attempt <= 3 ? 'retry' : 'finish' }
    
    input:
    path accessions_file
    path geo_metadata
    
    output:
    path '*.locations', emit: locations_tsv
    path 'warnings.txt', emit: warnings_txt
    
    script:
    """
    get_locations.py \
    -i ${accessions_file} \
    --geo ${geo_metadata}
    """
}

process PUBLISH_WARNINGS {

    publishDir(
    "${params.outdir}/additional_data/intermediate_files/",
    pattern: "ena_location_warnings.txt",
    mode: "copy",
    failOnError: true
    )
    
    input:
    path warning_file
    
    output:
    path "ena_location_warnings.txt"
    
    script:
    """
    mv all_warnings.txt ena_location_warnings.txt
    """

}


workflow METADATA_AND_PHYLOTREE {

    take:
        cluster_reps_fnas // list of .fna files for the cluster reps
        all_genomes_fnas // list of all the genomes .fna
        extra_weights_tsv
        check_results_tsv
        rrna_out_results
        name_mapping_tsv
        clusters_tsv
        ftp_name
        ftp_version
        geo_metadata
        gunc_failed_txt
        gtdbtk_tables_ch
    main:
        PREPARE_LOCATION_INPUT(
            gunc_failed_txt,
            name_mapping_tsv
        )
        
        location_input_chunks = PREPARE_LOCATION_INPUT.out.locations_input_tsv.splitText(
            by: 300,
            file: true
        )
        
        FETCH_LOCATIONS(
            location_input_chunks,
            geo_metadata
        )
        
        location_table = FETCH_LOCATIONS.out.locations_tsv.collectFile(
            name: "locations.tsv",
        )
        warning_file = FETCH_LOCATIONS.out.warnings_txt.collectFile(
            name: "all_warnings.txt",
        )
        
        PUBLISH_WARNINGS(
            warning_file
        )
        
        METADATA_TABLE(
            all_genomes_fnas,
            extra_weights_tsv,
            check_results_tsv,
            rrna_out_results,
            name_mapping_tsv,
            clusters_tsv,
            gtdbtk_tables_ch,
            ftp_name,
            ftp_version,
            location_table,
            gunc_failed_txt
        )

        PHYLO_TREE(gtdbtk_tables_ch)

    emit:
        metadata_tsv = METADATA_TABLE.out.metadata_tsv
        phylo_tree = PHYLO_TREE.out.phylo_tree
}
