#!/usr/bin/env cwl-runner
cwlVersion: v1.2.0-dev2
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
    out:
      - prokka_faa-s  # File[]
      - cluster_folder  # Dir
      - panaroo_folder  # Dir
      - prokka_folder  # Dir[]
      - genomes_folder  # Dir
      - mash_folder  # Dir

