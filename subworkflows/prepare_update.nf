/*
 * Prepare data for a catalogue update and performs sanity checks
 */
 
include { CHECK_CATALOGUE_STRUCTURE } from '../modules/check_catalogue_structure'
include { CHECK_GENOME_VALIDITY } from '../modules/check_genome_validity'
include { CHECKM2 as CHECKM2_CATALOGUE } from '../modules/checkm2'
include { EXTRACT_METADATA_FROM_TABLE } from '../modules/extract_info_from_metadata_table'
 
workflow PREPARE_UPDATE {
    take:
        previous_catalogue_location     // channel: file
        remove_genomes                  // channel: file
        skip_genome_validity_check      // true/false
        rerun_checkm2                   // true/false
        ch_checkm2_db
    main:
        CHECK_CATALOGUE_STRUCTURE(
            previous_catalogue_location
        )
        CHECK_CATALOGUE_STRUCTURE.out.check_catalogue_structure_result.view { file -> 
            if (file.name == "PREVIOUS_CATALOGUE_STRUCTURE_ERRORS.txt" ){
                error """
                There are missing files or folders in the catalogue to be updated. 
                Fix the errors listed in ${params.outdir}/additional_data/update_execution_reports/PREVIOUS_CATALOGUE_STRUCTURE_ERRORS.txt and restart the pipeline.
                """.stripIndent().trim()
             }
        }
        
        if ( !skip_genome_validity_check ) {
            CHECK_GENOME_VALIDITY(
                previous_catalogue_location,
                remove_genomes
            )
            CHECK_GENOME_VALIDITY.out.genome_validity_result.view { file -> 
                if (file.name == "GENOME_CHECK_FAILED_ACCESSIONS" ){
                    error """
                    Some genomes from the previous catalogue version could not be found in ENA. 
                    Review the report, add genomes that are correctly missing from ENA to the removal list, and restart the pipeline. 
                    Report: \${params.outdir}/additional_data/update_execution_reports/GENOME_CHECK_FAILED_ACCESSIONS
                    """.stripIndent().trim()
                }
            }
        }
        
        EXTRACT_METADATA_FROM_TABLE(
            "${previous_catalogue_location}/ftp/genomes-all_metadata.tsv"
        )
        
        if ( rerun_checkm2 ) {
            CHECKM2_CATALOGUE(
                "${previous_catalogue_location}/additional_data/mgyg_genomes/",
                ch_checkm2_db
            )
            previous_version_quality = CHECKM2_CATALOGUE.out.checkm_csv
        }
        else {
            previous_version_quality = EXTRACT_METADATA_FROM_TABLE.out.quality_csv
        }
    emit:
        previous_version_quality = previous_version_quality
        previous_version_assembly_stats = EXTRACT_METADATA_FROM_TABLE.out.assembly_stats_tsv
}