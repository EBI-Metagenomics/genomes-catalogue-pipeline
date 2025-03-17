/*
 * Functional annotation of the cluster rep genomes - prokaryotes and eukaryotes
*/

include { IPS } from '../modules/interproscan'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ORTHOLOGS } from '../modules/eggnog'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ANNOTATIONS } from '../modules/eggnog'

workflow ANNOTATE_EUKARYOTES {
    take:
        cluster_reps_faas
        interproscan_db
        eggnog_db
        eggnog_diamond_db
        eggnog_data_dir
        
    main:
        IPS(
            cluster_reps_faas,
            interproscan_db
        )

        EGGNOG_MAPPER_ORTHOLOGS(
            cluster_reps_faas,
            tuple("empty", "NO_FILE"),
            channel.value('mapper'),
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )

        EGGNOG_MAPPER_ANNOTATIONS(
            tuple("empty", "NO_FILE"),
            EGGNOG_MAPPER_ORTHOLOGS.out.orthologs,
            channel.value('annotations'),
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )
    
    emit:
        ips_annotation_tsvs = IPS.out.ips_annotations
        eggnog_annotation_tsvs = EGGNOG_MAPPER_ANNOTATIONS.out.annotations
}
        