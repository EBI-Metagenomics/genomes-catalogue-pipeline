/* TODO: improve description
 * Phylogenetic tree generation and metadata colleciton.
*/

include { METADATA_TABLE } from '../modules/metadata_table'
include { PHYLO_TREE } from '../modules/phylo_tree'

process PREPARE_LOCATION_INPUT {
    
    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    input:
    gunc_failed_txt
    name_mapping_tsv
    
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

process FETCH_LOCATIONS(

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    input:
    accessions_file
    geo_metadata
    
    output:
    path '*.locations', emit: locations_tsv
    
    script:
    """
    get_locations.py \
    -i ${accessions_file} \
    --geo ${geo_metadata}
    """
)

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
            by: 500,
            file: true
        )
        
        FETCH_LOCATIONS(
            location_input_chunks,
            geo_metadata
        )
        
        location_table = FETCH_LOCATIONS.out.locations_tsv.collectFile(
            name: "locations.tsv",
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
            geo_metadata,
            gunc_failed_txt
        )

        PHYLO_TREE(gtdbtk_tables_ch)

    emit:
        metadata_tsv = METADATA_TABLE.out.metadata_tsv
        phylo_tree = PHYLO_TREE.out.phylo_tree
}
