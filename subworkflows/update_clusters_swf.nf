/*
 * Update clusters (runs during catalogue update/reannotation only)
*/

include { QS50_FILTER_PREVIOUS_VERSION } from '../modules/filter_qs50_previous_version'
include { MASH_FOR_UPDATE } from '../modules/mash_for_update'
include { PARSE_MASH_FOR_UPDATE } from '../modules/parse_mash_for_update'
include { DREP } from '../modules/drep'
include { RUN_CLUSTER_UPDATE } from '../modules/run_cluster_update'
include { CLASSIFY_CLUSTERS } from '../modules/classify_clusters'
include { SPLIT_DREP as SPLIT_DREP_NEW_SPECIES } from '../modules/split_drep'
include { PRINT_DREP_FILES } from '../modules/print_drep_files'
include { MASH_COMPARE } from '../modules/mash_compare'
include { COMBINE_GENOME_FOLDERS } from '../modules/utils'

workflow UPDATE_CLUSTERS {
    take:
        previous_catalogue_location
        remove_genomes
        previous_version_quality_file
        previous_version_assembly_stats
        new_genomes
        new_data_checkm
        new_genome_stats
        extra_weight_table_new_genomes
        genomes_name_mapping
        drep_args
    main:
    
        // We only want to run modules on new genomes if new genomes are being added; make a queue channel for this
        new_genomes_present = new_genomes.filter { items ->
        items instanceof List ? !items.isEmpty() : true
        }
        
        // check if any genomes from the previous version fail QS50
        QS50_FILTER_PREVIOUS_VERSION (
            previous_version_quality_file,
            remove_genomes,
            "${previous_catalogue_location}/additional_data/mgyg_genomes/"
        )
        
        /////// STEP 1: measure distances between new genomes and the previous catalogue (as is)
        // Run mash if there are new genomes being added (if not, new_genomes is and empty channel)
        MASH_FOR_UPDATE (
            previous_catalogue_location,
            new_genomes_present
        )
        
        // Ensure mash_results exists even when process doesn't run (no genomes to add)
        mash_results = MASH_FOR_UPDATE.out.update_mash_out.ifEmpty(Channel.empty())
        
        /////// STEP 2: Use mash results to separate new genomes into new species, new strains and repeat strains
        PARSE_MASH_FOR_UPDATE (
            new_genomes_present,
            mash_results,
            previous_catalogue_location
        )
        
        /////// STEP 3: cluster new genomes that will form new catalogue species
        DREP (
            PARSE_MASH_FOR_UPDATE.out.new_species_folder,
            new_data_checkm,
            extra_weight_table_new_genomes,
            drep_args
        )
        
        SPLIT_DREP_NEW_SPECIES (
            DREP.out.cdb_csv,
            DREP.out.mdb_csv,
            DREP.out.sdb_csv
        )
        
         // TODO: make empty outputs if we are not adding anything to the catalogue
                       
        // gather genome stats and remake clusters
        // TODO: add new drep outputs to this
        RUN_CLUSTER_UPDATE (
            previous_catalogue_location,
            QS50_FILTER_PREVIOUS_VERSION.out.remove_list_mgyg_updated,
            previous_version_quality_file,
            previous_version_assembly_stats,
            new_data_checkm,
            new_genome_stats,
            extra_weight_table_new_genomes,
            genomes_name_mapping,
            PARSE_MASH_FOR_UPDATE.out.new_strains_file.ifEmpty([]),
            PARSE_MASH_FOR_UPDATE.out.repeat_strains_file.ifEmpty([]),
            SPLIT_DREP_NEW_SPECIES.out.text_split.ifEmpty([])
        )
       
       // gather old and new genomes into one folder (using new_genomes and not new_genomes_present intentionally -
       // this module needs to always run, even if we are not adding any genomes)
       combined_genomes = COMBINE_GENOME_FOLDERS(
            "${previous_catalogue_location}/additional_data/mgyg_genomes/",
            new_genomes
       )
    
        CLASSIFY_CLUSTERS (
            combined_genomes,
            RUN_CLUSTER_UPDATE.out.updated_text_split
        )
        
        groupGenomes = { fna_file ->
            def cluster = fna_file.parent.toString().tokenize("/")[-1]
            return tuple(cluster, fna_file)
        }
        
        single_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.one_genome_fnas | flatten | map(groupGenomes)
        many_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.many_genomes_fnas | flatten | map(groupGenomes)
        
        // Make mash splits
        MASH_COMPARE(
            many_genomes_fna_tuples | groupTuple
        )
        
    emit:
        // tuples (many_genomes and single_genomes) from classify_clusters.nf
        // text_split, Cdb, Sdb from RUN_CLUSTER_UPDATE (replace_species_representative.py + output of new species drep)
        // Mdb.csv and mash needs to be recomputed separately
        assembly_stats_all_genomes = RUN_CLUSTER_UPDATE.out.assembly_stats_all_genomes
        extra_weight_table_all_genomes = RUN_CLUSTER_UPDATE.out.extra_weight_table_all_genomes
        checkm_all_genomes = RUN_CLUSTER_UPDATE.out.checkm_all_genomes
        mash_splits = MASH_COMPARE.out.mash_split
        single_genomes_fna_tuples = single_genomes_fna_tuples
        many_genomes_fna_tuples = many_genomes_fna_tuples
        drep_split_text = RUN_CLUSTER_UPDATE.out.updated_text_split
        updated_genomes_name_mapping = RUN_CLUSTER_UPDATE.out.updated_genomes_name_mapping
        
}