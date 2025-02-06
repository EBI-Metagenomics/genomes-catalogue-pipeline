/*
 * Update clusters (runs during catalogue update/reannotation only)
*/

include { RUN_CLUSTER_UPDATE } from '../modules/run_cluster_update'

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
        RUN_CLUSTER_UPDATE (
            previous_catalogue_location,
            remove_genomes,
            previous_version_quality_file,
            previous_version_assembly_stats,
            new_data_checkm,
            new_genome_stats,
            extra_weight_table_new_genomes
        )
        // remake clusters

    emit:
        assembly_stats_all_genomes = RUN_CLUSTER_UPDATE.out.assembly_stats_all_genomes
}