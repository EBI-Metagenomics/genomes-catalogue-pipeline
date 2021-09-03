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
  input_fasta: File
  input_csv: File
  gunc_db_path: File

outputs:
  tsv:
    type: File
    outputSource: gunc/gunc_tsv
  flag:
    type: File
    outputSource:
      - filter/complete
      - filter/empty
    pickValue: first_non_null


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
      name:
        source: input_fasta
        valueFrom: $(self.nameroot)
    out:
      - complete
      - empty


