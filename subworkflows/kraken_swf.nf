/*
  Subworkflow to build a kraken db and bracken dbs
*/

include { KRAKEN2_PREPARE_GTDBTK_TAX; KRAKEN2_BUILD_LIBRARY; KRAKEN2_POSTPROCESSING; KRAKEN2_BUILD } from '../modules/kraken2.nf'
include { BRACKEN as BRACKEN_50 } from '../modules/bracken.nf'
include { BRACKEN as BRACKEN_100 } from '../modules/bracken.nf'
include { BRACKEN as BRACKEN_150 } from '../modules/bracken.nf'
include { BRACKEN as BRACKEN_200 } from '../modules/bracken.nf'
include { BRACKEN as BRACKEN_250 } from '../modules/bracken.nf'

workflow KRAKEN_SWF {
    take:
        gtdbtk_bac120
        gtdbtk_ar53
        cluster_reps_fnas
    main:

        kraken_db_name = channel.value("kraken2_db_${params.catalogue_name}_v${params.catalogue_version}")
       
       // Formats the gtdbtk tax and creates the kraken db directory //
        KRAKEN2_PREPARE_GTDBTK_TAX(
            gtdbtk_bac120.mix(gtdbtk_ar53).collectFile(name: "gtdbtk_concatenated.tsv", newLine: true),
            kraken_db_name,
            cluster_reps_fnas.collect() // this may have performance issues if > 2k (bash args limit)
        )

        kraken_db = KRAKEN2_PREPARE_GTDBTK_TAX.out.kraken_db

        KRAKEN2_BUILD_LIBRARY(
            KRAKEN2_PREPARE_GTDBTK_TAX.out.tax_annotated_fnas | flatten,
            kraken_db
        )

        KRAKEN2_BUILD(
            kraken_db,
            KRAKEN2_BUILD_LIBRARY.out.collectFile(name: "kraken_build_library.log")
        )

        BRACKEN_50(
            channel.value(50),
            KRAKEN2_BUILD.out.kraken_db
        )
        BRACKEN_100(
            channel.value(100),
            KRAKEN2_BUILD.out.kraken_db
        )
        BRACKEN_150(
            channel.value(150),
            KRAKEN2_BUILD.out.kraken_db
        )
        BRACKEN_200(
            channel.value(200),
            KRAKEN2_BUILD.out.kraken_db
        )
        BRACKEN_250(
            channel.value(250),
            KRAKEN2_BUILD.out.kraken_db
        )

        /*
        We are collecting the logs from bracken to force
        nextflow to run the post-processing after they are done.
        */
        KRAKEN2_POSTPROCESSING(
            KRAKEN2_BUILD.out.kraken_db,
            BRACKEN_50.out.mix(
                BRACKEN_100.out
            ).mix(
                BRACKEN_150.out
            ).mix(
                BRACKEN_200.out
            ).mix(
                BRACKEN_250.out
            ).collectFile(name: "bracken_output.log")
        )
    emit:
        krakendb = KRAKEN2_POSTPROCESSING.out.kraken_db
}