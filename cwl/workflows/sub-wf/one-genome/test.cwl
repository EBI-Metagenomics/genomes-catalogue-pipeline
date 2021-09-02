#!/usr/bin/env cwl-runner
cwlVersion: v1.2.0
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  cluster: Directory
  gunc_db_path: File
  csv: File

outputs:
  prokka_faa-s:
    type: File?
    outputSource: prokka/faa

steps:
  preparation:
    run: ../../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [files]

  gunc:
    run: gunc-subwf.cwl
    in:
      input_fasta:
        source: preparation/files
        valueFrom: $(self[0])
      input_csv: csv
      gunc_db_path: gunc_db_path
    out:
      - complete-flag
      - empty-flag

  prokka:
    when: $(Boolean(inputs.flag))
    run: ../../../tools/prokka/prokka.cwl
    in:
      flag: gunc/complete-flag
      fa_file:
        source: preparation/files
        valueFrom: $(self[0])
      outdirname: { default: prokka_output }
    out: [ faa, outdir ]