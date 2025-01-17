/*
 * Prepare data for a catalogue update and performs sanity checks
 */
 
include { CHECK_CATALOGUE_STRUCTURE } from '../modules/check_catalogue_structure'
include { CHECK_GENOME_VALIDITY } from '../modules/check_genome_validity'
 
workflow PREPARE_UPDATE {
    take:
        previous_catalogue_location     // channel: file
        remove_genomes                  // channel: file
        skip_genome_validity_check      // true/false
    main:
        CHECK_CATALOGUE_STRUCTURE(
            previous_catalogue_location
        )
        if ( !skip_genome_validity_check ) {
            CHECK_GENOME_VALIDITY(
                previous_catalogue_location,
                remove_genomes
            )
        }
}