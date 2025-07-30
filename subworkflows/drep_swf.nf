/*
 * De-replicate
 */

include { DREP } from '../modules/drep'
include { SPLIT_DREP } from '../modules/split_drep'
include { CLASSIFY_CLUSTERS } from '../modules/classify_clusters'

workflow DREP_SWF {
    take:
        genomes_directory
        checkm_csv
        extra_weight_table
        drep_args

    main:
        DREP(
            genomes_directory,
            checkm_csv,
            extra_weight_table,
            drep_args
        )

        SPLIT_DREP(
            DREP.out.cdb_csv,
            DREP.out.mdb_csv,
            DREP.out.sdb_csv
        )

        CLASSIFY_CLUSTERS(
            genomes_directory,
            SPLIT_DREP.out.text_split
        )

        groupGenomes = { fna_file ->
            def cluster = fna_file.parent.toString().tokenize("/")[-1]
            return tuple(cluster, fna_file)
        }
        many_genomes_fna_tuples = Channel.empty()
        single_genomes_fna_tuples = Channel.empty()
        many_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.many_genomes_fnas | flatten | map(groupGenomes)
        single_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.one_genome_fnas | flatten | map(groupGenomes)

    emit:
        many_genomes_fna_tuples = many_genomes_fna_tuples
        single_genomes_fna_tuples = single_genomes_fna_tuples
        drep_split_text = SPLIT_DREP.out.text_split
        mash_splits = SPLIT_DREP.out.mash_splits
        drep_cdb_csv = DREP.out.cdb_csv
        drep_mdb_csv = DREP.out.mdb_csv
        drep_sdb_csv = DREP.out.sdb_csv
}
