/*
 * Prepare the genomes, rename the .fasta and merge if multiples ena and ncbi folders are provided
 */

include { MERGE_NCBI_ENA } from '../modules/merge_ncbi_ena'
include { CHECKM2 as CHECKM2_NCBI } from '../modules/checkm2'
include { FILTER_QS50 } from '../modules/filter_qs50'
include { RENAME_FASTA } from '../modules/rename_fasta'
include { GENERATE_EXTRA_WEIGHT } from '../modules/generate_extra_weight'
include { CALCULATE_ASSEMBLY_STATS } from '../modules/precompute_assembly_stats'


workflow PREPARE_DATA {
    take:
        ena_assemblies_dir          // channel: path
        ena_genomes_checkm          // channel: file
        ncbi_assemblies_dir         // channel: path
        genomes_name_start          // val
        genomes_name_end            // val
        preassigned_accessions      // channel: file | empty
        genomes_prefix              // val
        per_genome_category         // file | empty
        per_study_genomes_category  // file | empty
        ch_checkm2_db
    main:
        genomes_ch = channel.empty()
        genomes_checkm_ch = channel.empty()
        genomes_busco_ch = file("NO_BUSCO_FILE")
        
        // If ncbi folder is present, prepare genome chunks for CheckM2
        if ( ncbi_assemblies_dir ) {
            // Create a channel of individual genome files from the ncbi_genomes folder
            ch_genomes_for_checkm2 = channel.fromPath("${params.ncbi_genomes}/*")
            // Buffer into chunks of N files
            ch_genome_checkm2_chunks = ch_genomes_for_checkm2
                .buffer(size: params.checkm2_chunk_size, remainder: true) 
        }

        if ( ncbi_assemblies_dir && ena_assemblies_dir ) {
            CHECKM2_NCBI(
                ch_genome_checkm2_chunks,
                ch_checkm2_db
            )
            checkm2_csv = CHECKM2_NCBI.out.checkm_csv
                .collectFile(
                    name: 'checkm2_results_merged.csv',
                    keepHeader: true,
                    skip: 1
            )
            MERGE_NCBI_ENA(
                ena_assemblies_dir,
                ncbi_assemblies_dir,
                checkm2_csv,
                ena_genomes_checkm
            )
            // Merged genomes folders and checkm values //
            genomes_ch = MERGE_NCBI_ENA.out.genomes
            genomes_checkm_ch = MERGE_NCBI_ENA.out.merged_checkm_csv
        } else if ( ncbi_assemblies_dir ) {
            CHECKM2_NCBI(
                ch_genome_checkm2_chunks,
                ch_checkm2_db
            )
            checkm2_csv = CHECKM2_NCBI.out.checkm_csv
                .collectFile(
                    name: 'checkm2_results_merged.csv',
                    keepHeader: true,
                    skip: 1
            )
            genomes_ch = ncbi_assemblies_dir
            genomes_checkm_ch = checkm2_csv
        } else if ( ena_assemblies_dir ) {
            genomes_ch = ena_assemblies_dir
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
            preassigned_accessions,
            FILTER_QS50.out.filtered_csv,
            genomes_prefix,
            genomes_busco_ch
        )

        GENERATE_EXTRA_WEIGHT(
            FILTER_QS50.out.filtered_genomes,
            RENAME_FASTA.out.rename_mapping,
            per_genome_category,
            per_study_genomes_category
        )
        
        CALCULATE_ASSEMBLY_STATS(
            RENAME_FASTA.out.renamed_genomes
        )

    emit:
        genomes = RENAME_FASTA.out.renamed_genomes
        genomes_checkm = RENAME_FASTA.out.renamed_checkm
        genomes_name_mapping = RENAME_FASTA.out.rename_mapping
        extra_weight_table = GENERATE_EXTRA_WEIGHT.out.extra_weight_table
        qs50_failed = FILTER_QS50.out.failed_genomes
        new_genome_stats = CALCULATE_ASSEMBLY_STATS.out.stats_file
}
