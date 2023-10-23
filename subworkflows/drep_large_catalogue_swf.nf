/*
 * De-replicate large catalogues > 100k genomes
 */

include { DREP_CHUNKED } from '../modules/drep_chunked'
include { DREP_CHUNKED as DREP_RERUN } from '../modules/drep_chunked'
include { COMBINE_CHUNKED_DREP } from '../modules/combine_chunked_drep'
include { SPLIT_DREP } from '../modules/split_drep'
include { CLASSIFY_CLUSTERS } from '../modules/classify_clusters'
include { MASH_COMPARE } from '../modules/mash_compare'

process COLLECT_DREP_RESULTS {

    publishDir(
        path: "${params.outdir}/additional_data/intermediate_files",
        mode: "copy",
        failOnError: true
    )

    stageInMode "copy"

    input:
    path drep_tables_tarballs
    path cdb_csv
    path sdb_csv
    path mdb_csv

    output:
    path "drep_data_tables.tar.gz"

    script:
    """
    tar -czf drep_data_tables.tar.gz \
        ${cdb_csv} \
        ${sdb_csv} \
        ${mdb_csv} \
        ${drep_tables_tarballs.join(' ')}
    """

}

workflow DREP_LARGE_SWF {
    take:
        genomes_directory
        checkm_csv
        extra_weight_table

    main:

        // split genomes from genomes_directory into chunks 25000 files each (probably doesnt work)
        genomes_chunked = genomes_directory
            .map( { dir -> files("${dir}/*.fa") })
            .flatten()
            .buffer( size: params.xlarge_chunk_size, remainder: true )

        // dRep each chunk
        DREP_CHUNKED(
            genomes_chunked,
            checkm_csv.first(),
            extra_weight_table.first(),
            false // not-merged - used for the output tarball name
        )

        dereplicated_genomes = DREP_CHUNKED.out.dereplicated_genomes.collect()

        // re-run dDrep on species representatives
        DREP_RERUN(
            dereplicated_genomes,
            checkm_csv,
            extra_weight_table,
            true // merged - used for the output tarball name
        )

        all_cdb_files = DREP_CHUNKED.out.cdb_csv.collect()
        all_sdb_files = DREP_CHUNKED.out.sdb_csv.collect()

        COMBINE_CHUNKED_DREP(
            all_cdb_files,
            all_sdb_files,
            DREP_RERUN.out.cdb_csv
        )

        SPLIT_DREP(
            COMBINE_CHUNKED_DREP.out.combined_cdb,
            file("NO_FILE"), // optional mdb file
            COMBINE_CHUNKED_DREP.out.combined_sdb,
        )

        CLASSIFY_CLUSTERS(
            genomes_directory,
            SPLIT_DREP.out.text_split
        )

        // The mdb.csv files are contacenated and published as a single file
        mdb_csv_collected = DREP_CHUNKED.out.mdb_csv.collectFile(
            keepHeader: true,
            name: "Mdb.csv"
        )

        COLLECT_DREP_RESULTS(
            DREP_CHUNKED.out.drep_data_tables_tarball.mix(DREP_RERUN.out.drep_data_tables_tarball).collect(),
            COMBINE_CHUNKED_DREP.out.combined_cdb,
            COMBINE_CHUNKED_DREP.out.combined_sdb,
            mdb_csv_collected
        )

        def groupGenomes = { fna_file ->
            def cluster = fna_file.parent.toString().tokenize("/")[-1]
            return tuple(cluster, fna_file)
        }

        many_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.many_genomes_fnas | flatten | map(groupGenomes)
        single_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.one_genome_fnas | flatten | map(groupGenomes)

        // Run mash on each group of fastas in many_genomes_fnas
        MASH_COMPARE(
            many_genomes_fna_tuples | groupTuple
        )

    emit:
        many_genomes_fna_tuples = many_genomes_fna_tuples
        single_genomes_fna_tuples = single_genomes_fna_tuples
        drep_split_text = SPLIT_DREP.out.text_split
        mash_splits = MASH_COMPARE.out.mash_split
        drep_cdb_csv = DREP_RERUN.out.cdb_csv
        drep_sdb_csv = DREP_RERUN.out.sdb_csv
        drep_mdb_csv = mdb_csv_collected
}
