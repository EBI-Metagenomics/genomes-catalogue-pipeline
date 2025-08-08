/*
 * Functional annotation of the cluster rep genomes - prokaryotes and eukaryotes
*/

include { IPS as IPS_PER_GENOME } from '../modules/interproscan'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ORTHOLOGS_PER_GENOME } from '../modules/eggnog'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ANNOTATIONS_PER_GENOME } from '../modules/eggnog'

workflow ANNOTATE_EUKARYOTES {
    take:
        cluster_reps_faas
        interproscan_db
        eggnog_db
        eggnog_diamond_db
        eggnog_data_dir
        
    main:
        IPS_PER_GENOME(
            cluster_reps_faas,
            interproscan_db
        )

        EGGNOG_MAPPER_ORTHOLOGS_PER_GENOME(
            cluster_reps_faas,
            cluster_reps_faas.map { tuple(it[0], "NO_FILE") },  // use the cluster rep names in position 0 of tuple to have correct names
            channel.value('mapper'),
            channel.value('eukaryota_broad'),
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )

        EGGNOG_MAPPER_ANNOTATIONS_PER_GENOME(
            cluster_reps_faas.map { tuple(it[0], "NO_FILE") },  // use the cluster rep names in position 0 of tuple to have correct names
            EGGNOG_MAPPER_ORTHOLOGS_PER_GENOME.out.orthologs,
            channel.value('annotations'),
            channel.value('eukaryota_broad'),
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )
    
    emit:
        ips_annotation_tsvs = IPS_PER_GENOME.out.ips_annotations
        eggnog_annotation_tsvs = EGGNOG_MAPPER_ANNOTATIONS_PER_GENOME.out.annotations
}
        