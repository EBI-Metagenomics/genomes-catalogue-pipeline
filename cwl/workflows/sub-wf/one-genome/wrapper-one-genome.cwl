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
    type: File[]
    outputSource: process_one_genome/prokka_faa-s

  cluster_folder_prokka:
    type: Directory[]
    outputSource: process_one_genome/cluster_folder_prokka
  cluster_folder_genome:
    type: Directory[]
    outputSource: process_one_genome/cluster_folder_genome

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
      - cluster_folder_prokka  # Dir
      - cluster_folder_genome  # Dir