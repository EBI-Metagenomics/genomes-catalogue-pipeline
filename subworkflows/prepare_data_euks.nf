/*
 * Prepare the genomes, rename the .fasta and merge if multiples ena and ncbi folders are provided
 */

include { MERGE_NCBI_ENA_EUKS       } from '../modules/merge_ncbi_ena'
include { BUSCO as BUSCO_NCBI       } from '../modules/busco'
include { BUSCO as BUSCO_ENA        } from '../modules/busco'
include { EUKCC                     } from '../modules/eukcc'
include { FILTER_QS50               } from '../modules/filter_qs50'
include { RENAME_FASTA              } from '../modules/rename_fasta'
include { GENERATE_EXTRA_WEIGHT     } from '../modules/generate_extra_weight'
include { CALCULATE_ASSEMBLY_STATS  } from '../modules/precompute_assembly_stats'


workflow PREPARE_DATA_EUKS {
    take:
        ena_assemblies              // channel: path
        ena_genomes_eukcc           // channel: file
        ncbi_assemblies             // channel: path
        genomes_name_start          // val
        genomes_name_end            // val
        preassigned_accessions      // channel: file | empty
        genomes_prefix              // val
        per_genome_category         // file | empty
        per_study_genomes_category  // file | empty
        eukcc_db
        busco_db
    main:
        genomes_ch = channel.empty()
        genomes_checkm_ch = channel.empty()

        // get channel per genome fasta in path
        if ( ena_assemblies ) {
        ena_genomes_ch = ena_assemblies
        .map { dir ->
            return file("${dir}/*.{fasta,fa,fna}")}
        .flatMap { fasta -> 
            return fasta }
        }    

        if ( ncbi_assemblies ) {
        ncbi_genomes_ch = ncbi_assemblies
        .map { dir ->
            return file("${dir}/*.{fasta,fa,fna}")}
        .flatMap { fasta -> 
            return fasta }
        }   

        if ( ncbi_assemblies && ena_assemblies ) {
            BUSCO_ENA( ena_genomes_ch, busco_db )
            ena_busco = BUSCO_ENA.out.busco_summary.collect()

            ena_busco_concatenated = ena_busco.collectFile(
                keepHeader: false,
                name: "ena_busco.csv"
            )

            BUSCO_NCBI( ncbi_genomes_ch, busco_db )
            ncbi_busco = BUSCO_NCBI.out.busco_summary.collect()

            ncbi_busco_concatenated = ncbi_busco.collectFile(
                keepHeader: false,
                name: "ncbi_busco.csv"
            )

            EUKCC( ncbi_genomes_ch, eukcc_db )
            ncbi_eukcc = EUKCC.out.eukcc_result.collect()
            ncbi_eukcc_concatenated = ncbi_eukcc.collectFile(
                keepHeader: true,
                name: "ncbi_eukcc.csv"
            )

            MERGE_NCBI_ENA_EUKS(
                ncbi_assemblies,
                ena_assemblies,
                ncbi_busco_concatenated,
                ena_busco_concatenated,
                ncbi_eukcc_concatenated,
                ena_genomes_eukcc
            )

            // Merged genomes folders and checkm values //
            genomes_ch = MERGE_NCBI_ENA_EUKS.out.genomes
            genomes_eukcc_ch = MERGE_NCBI_ENA_EUKS.out.merged_eukcc_csv
            genomes_busco_ch = MERGE_NCBI_ENA_EUKS.out.merged_busco_csv

        } else if ( ncbi_assemblies ) {
            BUSCO_NCBI( ncbi_genomes_ch, busco_db )
            ncbi_busco = BUSCO_NCBI.out.busco_summary.collect()

            ncbi_busco_concatenated = ncbi_busco.collectFile(
                keepHeader: false,
                name: "ncbi_busco.csv"
            )

            EUKCC( ncbi_genomes_ch, eukcc_db )
            ncbi_eukcc = EUKCC.out.eukcc_result.collect()
            ncbi_eukcc_concatenated = ncbi_eukcc.collectFile(
                keepHeader: true,
                name: "ncbi_eukcc.csv"
            )

            genomes_ch = ncbi_assemblies
            genomes_eukcc_ch = ncbi_eukcc_concatenated
            genomes_busco_ch = ncbi_busco_concatenated

        } else if ( ena_assemblies ) {
            BUSCO_ENA( ena_genomes_ch, busco_db )
            ena_busco = BUSCO_ENA.out.busco_summary.collect()

            ena_busco.view()

            ena_busco_concatenated = ena_busco.collectFile(
                keepHeader: false,
                name: "ena_busco.csv"
            )

            ena_busco_concatenated.view()
          
            genomes_ch = ena_assemblies
            genomes_eukcc_ch = ena_genomes_eukcc
            genomes_busco_ch = ena_busco_concatenated
        }

        // FILTER_QS50(
        //     genomes_ch,
        //     genomes_eukcc_ch
        // )

        // RENAME_FASTA(
        //     FILTER_QS50.out.filtered_genomes,
        //     genomes_name_start,
        //     genomes_name_end,
        //     preassigned_accessions,
        //     FILTER_QS50.out.filtered_csv,
        //     genomes_prefix
        // )

        // GENERATE_EXTRA_WEIGHT(
        //     FILTER_QS50.out.filtered_genomes,
        //     RENAME_FASTA.out.rename_mapping,
        //     per_genome_category,
        //     per_study_genomes_category
        // )
        
        // CALCULATE_ASSEMBLY_STATS(
        //     RENAME_FASTA.out.renamed_genomes
        // )

    // emit:
    //     genomes = RENAME_FASTA.out.renamed_genomes
    //     genomes_checkm = RENAME_FASTA.out.renamed_checkm // this is eukcc not checkm but will leave naming for now
    //     genomes_name_mapping = RENAME_FASTA.out.rename_mapping
    //     extra_weight_table = GENERATE_EXTRA_WEIGHT.out.extra_weight_table
    //     qs50_failed = FILTER_QS50.out.failed_genomes
    //     new_genome_stats = CALCULATE_ASSEMBLY_STATS.out.stats_file
    //     genomes_busco = genomes_busco_ch // additional busco file for eukaryotes
}
