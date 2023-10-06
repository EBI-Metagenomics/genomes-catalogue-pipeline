/*
 * De-replicate large catalogues > 100k genomes
 */

include { DREP_CHUNKED } from '../modules/drep_chunked'
include { DREP_RERUN } from '../modules/drep_chunked'
include { COMBINE_CHUNKED_DREP } from '../modules/combine_chunked_drep'
include { SPLIT_DREP_LARGE } from '../modules/split_drep_large'
include { CLASSIFY_CLUSTERS } from '../modules/classify_clusters'
include { MASH_COMPARE } from '../modules/mash_compare'

workflow DREP_LARGE_SWF {
    take:
        genomes_directory
        checkm_csv
        extra_weight_table

    main:

        // split genomes from genomes_directory into chunks 25000 files each (probably doesnt work)
        genomes_chunked = Channel.fromPath( "${genomes_directory}/*.{fa,fasta,fna}" )
            .buffer( size: params.xlarge_chunk_size, remainder: true )

        // dRep each chunk
        DREP_CHUNKED(
            genomes_chunked,
            checkm_csv,
            extra_weight_table
        )

        dereplicated_genomes = DREP_CHUNKED.out.dereplicated_genomes.collect().flatten()

        // re-run dDrep on species representatives
        DREP_RERUN(
            dereplicated_genomes,
            checkm_csv,
            extra_weight_table
        )

        all_cdb_files = DREP_CHUNKED.out.cdb_csv.collect()
        all_sdb_files = DREP_CHUNKED.out.sdb_csv.collect()

        COMBINE_CHUNKED_DREP(
            all_cdb_files,
            all_sdb_files,
            DREP_RERUN.out.cbd_csv
        )

        SPLIT_DREP_LARGE(
            DREP.out.cdb_csv,
            DREP.out.sdb_csv
        )

        CLASSIFY_CLUSTERS(
            genomes_directory,
            SPLIT_DREP.out.text_split
        )

        // The mdb.csv files are contacenated and published a singile file
        mdb_csv_collected = COMBINE_CHUNKED_DREP.out.mdb_csv.collectFile(
            keepHeader: true,
            skip: 1,
            name: "Mdb.csv",
            storeDir: "${params.outdir}/additional_data/intermediate_files/"
        )

        def groupGenomes = { fna_file ->
            def cluster = fna_file.parent.toString().tokenize("/")[-1]
            return tuple(cluster, fna_file)
        }

        many_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.many_genomes_fnas | flatten | map(groupGenomes)
        single_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.one_genome_fnas | flatten | map(groupGenomes)

        // Run mash on each group of fastas in many_genomes_fnas
        MASH_COMPARE(
            many_genomes_fna_tuples
        )

    emit:
        many_genomes_fna_tuples = many_genomes_fna_tuples
        single_genomes_fna_tuples = single_genomes_fna_tuples
        drep_split_text = SPLIT_DREP_LARGE.out.text_split
        mash_splits = MASH_COMPARE.out.mash_split
        drep_cdb_csv = DREP_RERUN.out.cdb_csv
        drep_sdb_csv = DREP_RERUN.out.sdb_csv
        drep_mdb_csv = DREP.out.mdb_csv_collected
}
