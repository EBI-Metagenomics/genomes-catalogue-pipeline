/* TODO: improve description
 * GTDB TK for taxonomic assignment
 * Phylogenetic tree generation and metadata colleciton.
*/

include { GTDBTK } from '../modules/gtdbtk'
include { METADATA_TABLE } from '../modules/metadata_table'
include { PHYLO_TREE } from '../modules/phylo_tree'

workflow GTDBTK_AND_METADATA {

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
        gtdbtk_refdata
    main:
        GTDBTK(
            cluster_reps_fnas,
            gtdbtk_refdata
        )

        gtdbtk_tables_ch = channel.empty().mix(
            GTDBTK.out.gtdbtk_summary_bac120,
            GTDBTK.out.gtdbtk_summary_arc53
        ).collectFile(name: 'gtdbtk.summary.tsv')

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
            gunc_failed_txt.first()
        )

        PHYLO_TREE(gtdbtk_tables_ch)

    emit:
        gtdbtk_folder = gtdbtk_tables_ch
        gtdbtk_user_msa_bac120 = GTDBTK.out.gtdbtk_user_msa_bac120
        gtdbtk_user_msa_ar53 = GTDBTK.out.gtdbtk_user_msa_ar53
        gtdbtk_summary_bac120 = GTDBTK.out.gtdbtk_summary_bac120
        gtdbtk_summary_arc53 = GTDBTK.out.gtdbtk_summary_arc53
        metadata_tsv = METADATA_TABLE.out.metadata_tsv
        phylo_tree = PHYLO_TREE.out.phylo_tree
}
