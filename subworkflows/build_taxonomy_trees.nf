include { IQTREE as IQTREE_BAC                            } from '../modules/iqtree'
include { IQTREE as IQTREE_AR                             } from '../modules/iqtree'
include { FASTTREE as FASTTREE_BAC                        } from '../modules/fasttree'
include { FASTTREE as FASTTREE_AR                         } from '../modules/fasttree'
include { GENERATE_ITOL_FILES as GENERATE_ITOL_FILES_BAC  } from '../modules/itol_format_generation.nf'
include { GENERATE_ITOL_FILES as GENERATE_ITOL_FILES_ARC  } from '../modules/itol_format_generation.nf'

workflow BUILD_TAXONOMY_TREES {

    take:
        bac_user_msa
        arc_user_msa
        bac_gtdb_summary
        arc_gtdb_summary
        prefix_bac
        prefix_arc
        metadata_table
    main:

    /*
    IQTree needs at least 3 sequences, but it's too slow for more than 2000 sequences so we use FastTree in that case
    */
    def treeCreationCriteria = branchCriteria {
        iqtree: file(it).countFasta() > 2 && file(it).countFasta() < 2000
        fasttree: file(it).countFasta() >= 2000
    }

    bac_user_msa.branch( treeCreationCriteria ).set { gtdbtk_user_msa_bac120 }

    IQTREE_BAC(
        gtdbtk_user_msa_bac120.iqtree,
        prefix_bac
    )
    FASTTREE_BAC(
        gtdbtk_user_msa_bac120.fasttree,
        prefix_bac
    )

    arc_user_msa.branch( treeCreationCriteria ).set{ gtdbtk_user_msa_ar53 }

    IQTREE_AR(
        gtdbtk_user_msa_ar53.iqtree,
        prefix_arc
    )
    FASTTREE_AR(
        gtdbtk_user_msa_ar53.fasttree,
        prefix_arc
    )
    
    GENERATE_ITOL_FILES_BAC (
        bac_gtdb_summary.filter { it.name != 'EMPTY' },
        metadata_table,
        params.itol_taxa_level,
        channel.value("bac")
    )
    
    GENERATE_ITOL_FILES_ARC (
        arc_gtdb_summary.filter { it.name != 'EMPTY' },
        metadata_table,
        params.itol_taxa_level,
        channel.value("arc")
    )
}