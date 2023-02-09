/*
  Subworkflow to generate the protein databases using mmseq
*/

include { MMSEQ as MMSEQ_100 } from '../modules/mmseq'
include { MMSEQ as MMSEQ_95 } from '../modules/mmseq'
include { MMSEQ as MMSEQ_90 } from '../modules/mmseq'
include { MMSEQ as MMSEQ_50 } from '../modules/mmseq'

workflow MMSEQ_SWF {
    take:
        pangenome_prokka_faas
        singleton_prokka_faas
        renamed_genomes_csv
        mmseq_coverage_threshold
    main:

        proteins_ch = pangenome_prokka_faas.mix(singleton_prokka_faas) \
            .collectFile(name: 'proteins.faa')

        mmseq_100 = MMSEQ_100(
            proteins_ch,
            channel.value(1.0),
            mmseq_coverage_threshold
        )
        mmseq_95 = MMSEQ_95(
            proteins_ch,
            channel.value(0.95),
            mmseq_coverage_threshold
        )
        mmseq_90 = MMSEQ_90(
            proteins_ch,
            channel.value(0.90),
            mmseq_coverage_threshold
        )
        mmseq_50 = MMSEQ_50(
            proteins_ch,
            channel.value(0.50),
            mmseq_coverage_threshold
        )
    emit:
        mmseq_cluster_rep_faa = mmseq_90.mmseq_cluster_rep_faa
        mmseq_cluster_tsv = mmseq_90.mmseq_cluster_tsv
}
