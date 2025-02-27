/*
 * Update clusters (runs during catalogue update/reannotation only)
*/

include { RUN_CLUSTER_UPDATE } from '../modules/run_cluster_update'
include { CLASSIFY_CLUSTERS } from '../modules/classify_clusters'

workflow UPDATE_CLUSTERS {
    take:
        previous_catalogue_location
        remove_genomes
        previous_version_quality_file
        previous_version_assembly_stats
        new_data_checkm
        new_genome_stats
        extra_weight_table_new_genomes
    main:
        // run mash
        // parse mash - keep mind that script might need to be modified because before we ran mash with 0.05 cut-off
        // cluster new species
        // run GUNC on singletons
        
        // gather genome stats and remake clusters
        RUN_CLUSTER_UPDATE (
            previous_catalogue_location,
            remove_genomes,
            previous_version_quality_file,
            previous_version_assembly_stats,
            new_data_checkm,
            new_genome_stats,
            extra_weight_table_new_genomes
        )
        
        // gather all genomes into one folder, run classify_clusters.nf on it (using the clusters_split file)
        CLASSIFY_CLUSTERS (
            // temporary solution, replace with all genomes folder
            "${previous_catalogue_location}/additional_data/mgyg_genomes/",
            RUN_CLUSTER_UPDATE.out.updated_text_split
        )
        
        groupGenomes = { fna_file ->
            def cluster = fna_file.parent.toString().tokenize("/")[-1]
            return tuple(cluster, fna_file)
        }
        
    emit:
        // tuples (many_genomes and single_genomes) from classify_clusters.nf
        // text_split, Cdb, Sdb from RUN_CLUSTER_UPDATE (replace_species_representative.py + output of new species drep)
        // Mdb.csv and mash needs to be recomputed separately
        assembly_stats_all_genomes = RUN_CLUSTER_UPDATE.out.assembly_stats_all_genomes
        mash_splits = file("EMPTY_FILE")
        single_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.one_genome_fnas | flatten | map(groupGenomes)
        many_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.many_genomes_fnas | flatten | map(groupGenomes)
        drep_split_text = RUN_CLUSTER_UPDATE.out.updated_text_split
        
}