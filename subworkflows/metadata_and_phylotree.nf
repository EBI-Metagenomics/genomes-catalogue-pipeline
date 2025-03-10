/* TODO: improve description
 * Phylogenetic tree generation and metadata colleciton.
*/

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
    main:
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
            gunc_failed_txt,
            ch_previous_catalogue_location,
            all_assembly_stats
        )

        PHYLO_TREE(gtdbtk_tables_ch)

    emit:
        metadata_tsv = METADATA_TABLE.out.metadata_tsv
        phylo_tree = PHYLO_TREE.out.phylo_tree
}
