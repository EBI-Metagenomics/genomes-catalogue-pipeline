#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  input_fasta: File
  input_csv: File
  gunc_db_path: string

outputs:
  complete-flag:
    type: File?
    outputSource: filter/complete
  empty-flag:
    type: File?
    outputSource: filter/empty

steps:
  gunc:
    run: ../../../tools/GUNC/gunc.cwl
    in:
      input_fasta: input_fasta
      db_path: gunc_db_path
    out: [ gunc_tsv ]

  filter:
    run: ../../../tools/GUNC/filter_gunc.cwl
    in:
      csv: input_csv
      gunc: gunc/gunc_tsv
    out:
      - complete
      - empty

