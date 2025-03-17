#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { GAP_EUKS } from './workflows/genomes_annotation_euks'
include { GAP } from './workflows/genomes_annotation'

workflow {
    if (params.kingdom == 'eukaryotes') {
        println "Running GAP_EUKS workflow for eukaryotes"
        GAP_EUKS()
    } else {
        println "Running GAP workflow for non-eukaryotes"
        GAP()
    }
}
