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
  checkm_out:
    type: File
    outputSource: checkm/stdout
  checkm_err:
    type: File
    outputSource: checkm/stderr
  checkm_csv:
    type: File
    outputSource: checkm2csv/csv

steps:

  checkm:
    run: ../../tools/checkm/checkm.cwl
    in:
      input_folder: genomes_folder
      checkm_outfolder: { default: 'checkm_outfolder' }
    out: [ stdout, stderr ]

  checkm2csv:
    run: ../../tools/checkm2csv/checkm2csv.cwl
    in:
      out_checkm: checkm/stdout
    out: [ csv ]
