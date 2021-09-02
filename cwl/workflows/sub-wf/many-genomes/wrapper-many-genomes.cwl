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
  input_clusters: Directory[]
  mash_folder: File[]
  InterProScan_databases: [string, Directory]
  chunk_size_IPS: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

outputs:
  mash_folder:
    type: Directory[]
    outputSource: process_many_genomes/mash_folder

  many_genomes:
    type: Directory[]
    outputSource: process_many_genomes/cluster_folder
  many_genomes_panaroo:
    type: Directory[]
    outputSource: process_many_genomes/panaroo_folder
  many_genomes_prokka:
    type:
      type: array
      items:
        type: array
        items: Directory
    outputSource: process_many_genomes/prokka_folder
  prokka_seqs:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: process_many_genomes/prokka_faa-s
  many_genomes_genomes:
    type: Directory[]
    outputSource: process_many_genomes/genomes_folder

steps:

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    run: sub-wf-many-genomes.cwl
    scatter: cluster
    in:
      cluster: input_clusters
      mash_files: mash_folder
      InterProScan_databases: InterProScan_databases
      chunk_size_IPS: chunk_size_IPS
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog
    out:
      - prokka_faa-s  # File[]
      - cluster_folder  # Dir
      - panaroo_folder  # Dir
      - prokka_folder  # Dir[]
      - genomes_folder  # Dir
      - mash_folder  # Dir

