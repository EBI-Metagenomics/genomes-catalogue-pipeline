/*
  Subworkflow to build the kraken db
*/

include { KRAKEN2_PREPARE_GTDBTK_TAX, KRAKEN2_BUILD_LIBRARY } from '../modules/kraken2.nf'
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
        KRAKEN2_PREPARE_GTDBTK_TAX(
            gtdbtk_bac120,
            gtdbtk_ar53,
            kraken_db // TODO
        )
        // -- kraken_intermediate

        KRAKEN2_BUILD_LIBRARY(
            cluster_reps_fnas,
            kraken_db
        )

    BRACKEN_50(
        channel.value(50),
        kraken_db
    )
    BRACKEN_100(
        channel.value(100),
        kraken_db
    )
    BRACKEN_150(
        channel.value(150),
        kraken_db
    )
    BRACKEN_200(
        channel.value(200),
        kraken_db
    )
    BRACKEN_250(
        channel.value(250),
        kraken_db
    )
    emit:
    // TODO: kraken_db
}