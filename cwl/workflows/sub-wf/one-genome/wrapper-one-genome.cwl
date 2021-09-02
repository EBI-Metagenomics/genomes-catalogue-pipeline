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

  InterProScan_databases: [string, Directory]
  chunk_size_IPS: int

  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

outputs:

  prokka_faa-s:
    type: File[]
    outputSource: process_one_genome/prokka_faa-s

  cluster_folder:
    type: Directory[]
    outputSource: process_one_genome/cluster_folder
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
      InterProScan_databases: InterProScan_databases
      chunk_size_IPS: chunk_size_IPS
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog
    out:
      - prokka_faa-s  # File
      - cluster_folder  # Dir
      - cluster_folder_prokka  # Dir
      - cluster_folder_genome  # Dir