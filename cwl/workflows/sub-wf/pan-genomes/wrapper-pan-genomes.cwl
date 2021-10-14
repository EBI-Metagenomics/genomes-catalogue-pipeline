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
  input_clusters: Directory[]
  mash_folder: File[]

outputs:

  pangenome_clusters:
    type: Directory[]
    outputSource: process_many_genomes/cluster_folder

  prokka_seqs:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: process_many_genomes/prokka_faa-s


steps:

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    run: sub-wf-pan-genomes.cwl
    scatter: cluster
    in:
      cluster: input_clusters
      mash_files: mash_folder
    out:
      - prokka_faa-s  # File[]
      - cluster_folder  # Dir

