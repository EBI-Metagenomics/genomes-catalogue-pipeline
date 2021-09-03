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
    outputSource: filter_nulls_prokka/out_files    # 'null', File[]

  cluster_folder:
    type: Directory[]
    outputSource: process_one_genome/cluster_dir

  gunc_decisions:
    type: Directory
    outputSource: create_gunc_folder/out

steps:
  process_one_genome:
    run: sub-wf-one-genome.cwl
    scatter: cluster
    in:
      cluster: input_cluster
      csv: csv
      gunc_db_path: gunc_db_path
    out:
      - prokka_faa-s  # File
      - cluster_dir  # Dir
      - gunc_decision # File

  create_gunc_folder:
    run: ../../../utils/return_directory.cwl
    in:
      list: process_one_genome/gunc_decision
      dir_name: {default: "gunc_output"}
    out: [out]


  filter_nulls_prokka:
    run: ../../../utils/filter_nulls.cwl
    in:
      list_files: process_one_genome/prokka_faa-s
    out: [ out_files ]

