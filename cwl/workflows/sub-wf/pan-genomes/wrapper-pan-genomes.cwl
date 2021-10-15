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

  prokka_gffs:
    type: File[]
    outputSource: flatten_gffs/array1d


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
      - prokka_gff-s
      - cluster_folder  # Dir

  flatten_gffs:
    run: ../../../utils/flatten_array.cwl
    in:
      arrayTwoDim: process_many_genomes/prokka_gff-s
    out: [ array1d ]

