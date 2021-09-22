#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  genomes_folder: Directory

outputs:
  taxcheck_dir:
    type: Directory
    outputSource: return_taxcheck_dir/pool_directory

steps:
# ----------- << taxcheck >> -----------
  prep_taxcheck:
    run: ../../utils/get_files_from_dir.cwl
    in:
      dir: genomes_folder
    out: [files]

  taxcheck:
    run: ../../tools/taxcheck/taxcheck.cwl
    scatter: genomes_fasta
    in:
      genomes_fasta: prep_taxcheck/files
      taxcheck_outfolder: { default: 'taxcheck'}
      taxcheck_outname: { default: 'taxcheck'}
    out: [ taxcheck_folder ]

  return_taxcheck_dir:
    run: ../../utils/return_dir_of_dir.cwl
    in:
      directory_array: taxcheck/taxcheck_folder
      newname: { default: "taxcheck_output" }
    out: [ pool_directory ]