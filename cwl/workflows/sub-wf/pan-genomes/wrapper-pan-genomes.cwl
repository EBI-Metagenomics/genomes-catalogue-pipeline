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

  panaroo_output:
    type: Directory
    outputSource: panaroo_final_folder/out

  initial_genomes_fa-s:
    type: File[]
    outputSource: flatten_fa-s/array1d
  main_reps_faa:
    type: File[]
    outputSource: process_many_genomes/main_rep_faa
  main_reps_gff:
    type: File[]
    outputSource: process_many_genomes/main_rep_gff
  core_genes_files:
    type: File[]
    outputSource: process_many_genomes/core_genes
  pangenome_fnas:
    type: File[]
    outputSource: process_many_genomes/pangenome_fna

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
      - panaroo_tar     # File[]
      - initial_genomes_fa  # File[]
      - main_rep_gff
      - main_rep_faa
      - core_genes
      - pangenome_fna

  flatten_gffs:
    run: ../../../utils/flatten_array.cwl
    in:
      arrayTwoDim: process_many_genomes/prokka_gff-s
    out: [ array1d ]

  flatten_fa-s:
    run: ../../../utils/flatten_array.cwl
    in:
      arrayTwoDim: process_many_genomes/initial_genomes_fa
    out: [ array1d ]

  panaroo_final_folder:
    run: ../../../utils/return_directory.cwl
    in:
      list: process_many_genomes/panaroo_tar
      dir_name: { default: panaroo_output }
    out: [ out ]
