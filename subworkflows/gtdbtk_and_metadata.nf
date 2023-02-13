/* TODO: improve description
 * GTDB TK for taxonomic assignment
 * Phylogenetic tree generation and metadata colleciton.
*/

include { GTDBTK } from '../modules/gtdbtk'
include { METADATA_TABLE } from '../modules/metadata_table'
include { PHYLO_TREE } from '../modules/phylo_tree'

// include { COLLECT_INTO_DIR } from '../modules/collect_into_dir'

workflow GTDBTK_AND_METADATA {

    take:
        drep_folder
        extra_weights_tsv
        check_results_tsv
        rrna_out_results
        name_mapping_tsv
        clusters_tsv
        ftp_name
        ftp_version
        geo_metadata
        gunc_failed_tsv
        gtdbtk_refdata
    main:
        GTDBTK(
            drep_folder,
            gtdbtk_refdata
        )

        gtdbtk_tables_ch = channel.empty().mix(
            GTDBTK.out.gtdbtk_bac,
            GTDBTK.out.gtdbtk_arc
        ).collectFile(name: 'gtdbtk.summary.tsv')

        METADATA_TABLE(
            drep_folder,
            extra_weights_tsv,
            check_results_tsv,
            rrna_out_results,
            name_mapping_tsv,
            clusters_tsv,
            gtdbtk_tables_ch,
            ftp_name,
            ftp_version,
            geo_metadata,
            gunc_failed_tsv
        )

        PHYLO_TREE(gtdbtk_tables_ch)

    emit:
        gtdbtk_folder = gtdbtk_tables_ch
        gtdbtk_msa_bac120 = gtdb.out.gtdbtk_msa_bac120
        gtdbtk_msa_ar53 = gtdb.out.gtdbtk_msa_ar53
        metadata_tsv = METADATA_TABLE.out.metadata_tsv
        phylo_tree = PHYLO_TREE.out.phylo_tree
}
