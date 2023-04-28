#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { GAP } from './workflows/genomes_annotation'

workflow {
    GAP ()
}
