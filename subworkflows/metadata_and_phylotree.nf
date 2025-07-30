/* TODO: improve description
 * Phylogenetic tree generation and metadata colleciton.
*/

include { PREPARE_LOCATION_INPUT } from '../modules/utils'
include { FETCH_LOCATIONS } from '../modules/utils'
include { METADATA_TABLE } from '../modules/metadata_table'
include { PHYLO_TREE } from '../modules/phylo_tree'

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
        ch_previous_catalogue_location
        all_assembly_stats
        busco_summary
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

        FETCH_LOCATIONS.out.warnings_txt.collectFile(
            name: "ena_location_warnings.txt", storeDir: "${params.outdir}/additional_data/intermediate_files/"
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
            gunc_failed_txt,
            ch_previous_catalogue_location,
            all_assembly_stats,
            busco_summary
        )

        PHYLO_TREE(gtdbtk_tables_ch)

    emit:
        metadata_tsv = METADATA_TABLE.out.metadata_tsv
        phylo_tree = PHYLO_TREE.out.phylo_tree
}
