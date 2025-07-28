#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

if (params.kingdom == 'eukaryotes') {
    include { GAP_EUKS } from './workflows/genomes_annotation_euks'
} else {
    include { GAP } from './workflows/genomes_annotation'
}

workflow {
    if (params.kingdom == 'eukaryotes') {
        println "Running GAP_EUKS workflow for eukaryotes"
        GAP_EUKS()
    } else if (params.kingdom == 'prokaryotes') {
        println "Running GAP workflow for non-eukaryotes"
        GAP()
    } else {
        error "Invalid kingdom parameter: '${params.kingdom}'. Valid options are: 'eukaryotes', 'prokaryotes'"
    }
}
