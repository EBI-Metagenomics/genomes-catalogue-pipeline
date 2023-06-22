/*
 * Prepare the genomes, rename the .fasta and merge if multiples ena and ncbi folders are provided
 */

include { MERGE_NCBI_ENA } from '../modules/merge_ncbi_ena'
include { CHECKM } from '../modules/checkm'
include { FILTER_QS50 } from '../modules/filter_qs50'
include { RENAME_FASTA } from '../modules/rename_fasta'
include { GENERATE_EXTRA_WEIGHT } from '../modules/generate_extra_weight'


workflow PREPARE_DATA {
    take:
        ena_assemblies              // channel: path
        ena_genomes_checkm          // channel: file
        ncbi_assemblies             // channel: path
        genomes_name_start          // val
        genomes_name_end            // val
        genomes_prefix              // val
        per_genome_category         // file | empty
        per_study_genomes_category  // file | empty
    main:
        genomes_ch = channel.empty()
        genomes_checkm_ch = channel.empty()

        if (ncbi_assemblies.toList() == true && ena_assemblies.toList() == true) {
            CHECKM(
                ncbi_assemblies
            )
            MERGE_NCBI_ENA(
                ena_assemblies,
                ncbi_assemblies,
                CHECKM.out.checkm_csv,
                ena_genomes_checkm
            )
            // Merged genomes folders and checkm values //
            genomes_ch = MERGE_NCBI_ENA.out.genomes
            genomes_checkm_ch = CHECKM.out.checkm_csv
        } else if (ncbi_assemblies.toList() == true) {
            CHECKM(
                ncbi_assemblies
            )
            genomes_ch = ncbi_assemblies
            genomes_checkm_ch = CHECKM.out.checkm_csv
        } else if (ena_assemblies) {
            genomes_ch = ena_assemblies
            genomes_checkm_ch = ena_genomes_checkm
        }

        FILTER_QS50(
            genomes_ch,
            genomes_checkm_ch
        )

        RENAME_FASTA(
            FILTER_QS50.out.filtered_genomes,
            genomes_name_start,
            genomes_name_end,
            FILTER_QS50.out.filtered_csv,
            genomes_prefix
        )

        GENERATE_EXTRA_WEIGHT(
            FILTER_QS50.out.filtered_genomes,
            RENAME_FASTA.out.rename_mapping,
            per_genome_category.ifEmpty(file("NO_FILE_GENOME_CAT")).first(),
            per_study_genomes_category.ifEmpty(file("NO_FILE_STUDY_CAT")).first()
        )

    emit:
        genomes = RENAME_FASTA.out.renamed_genomes
        genomes_checkm = RENAME_FASTA.out.renamed_checkm
        genomes_name_mapping = RENAME_FASTA.out.rename_mapping
        extra_weight_table = GENERATE_EXTRA_WEIGHT.out.extra_weight_table
}
