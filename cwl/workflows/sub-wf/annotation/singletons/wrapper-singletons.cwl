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
  input_cluster: Directory[]
  csv: File
  gunc_db_path: File

outputs:

  prokka_faa-s:
    type: File[]?
    outputSource: filter_nulls_prokka/out_files  #process_one_genome/prokka_faa
  prokka_gff-s:
    type: File[]?
    outputSource: filter_nulls_prokka_gff/out_files  #process_one_genome/prokka_gff

  cluster_folder:
    type: Directory[]
    outputSource: process_one_genome/cluster_dir

  gunc_completed:
    type: File
    outputSource: create_gunc_reports/report_completed
  gunc_failed:
    type: File
    outputSource: create_gunc_reports/report_failed

  filtered_initial_fa-s:
    type: File[]?
    outputSource: filter_nulls_fa-s/out_files

steps:
  process_one_genome:
    run: sub-wf-singleton.cwl
    scatter: cluster
    in:
      cluster: input_cluster
      csv: csv
      gunc_db_path: gunc_db_path
    out:
      - prokka_faa  # File
      - prokka_gff
      - cluster_dir   # Dir
      - gunc_decision # File
      - initial_fa  # File?

  create_gunc_reports:
    run: ../../../../tools/GUNC/generate_report.cwl
    in:
      input: process_one_genome/gunc_decision
    out:
      - report_completed
      - report_failed

  filter_nulls_prokka:
    run: ../../../../utils/filter_nulls.cwl
    in:
      list_files: process_one_genome/prokka_faa
    out: [ out_files ]

  filter_nulls_prokka_gff:
    run: ../../../../utils/filter_nulls.cwl
    in:
      list_files: process_one_genome/prokka_gff
    out: [ out_files ]

  filter_nulls_fa-s:
    run: ../../../../utils/filter_nulls.cwl
    in:
      list_files: process_one_genome/initial_fa
    out: [ out_files ]