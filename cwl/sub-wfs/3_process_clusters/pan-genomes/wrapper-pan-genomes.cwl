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

  panaroo_output:
    type: Directory
    outputSource: panaroo_final_folder/out

  other_pangenome_gffs:
    type: File[]
    outputSource: flatten_other_gffs/array1d
  all_pangenome_faa:
    type: File[]
    outputSource: flatten_faas/array1d

  reps_fna:
    type: File[]
    outputSource: process_many_genomes/main_rep_fna
  pangenome_other_fnas:
    type: File[]
    outputSource: flatten_other_fnas/array1d

  pangenome_clusters:
    type: Directory[]
    outputSource: process_many_genomes/pangenome_cluster

steps:

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    run: sub-wf-pan-genomes.cwl
    scatter: cluster
    in:
      cluster: input_clusters
      mash_files: mash_folder
    out:
      - panaroo_tar
      - pangenome_other_fnas
      - all_pangenome_faa
      - pangenome_cluster
      - pangenome_other_gffs
      - main_rep_fna

  flatten_other_gffs:
    run: ../../../utils/flatten_array.cwl
    in:
      arrayTwoDim: process_many_genomes/pangenome_other_gffs
    out: [ array1d ]

  flatten_other_fnas:
    run: ../../../utils/flatten_array.cwl
    in:
      arrayTwoDim: process_many_genomes/pangenome_other_fnas
    out: [ array1d ]

  flatten_faas:
    run: ../../../utils/flatten_array.cwl
    in:
      arrayTwoDim: process_many_genomes/all_pangenome_faa
    out: [ array1d ]

  panaroo_final_folder:
    run: ../../../utils/return_directory.cwl
    in:
      list: process_many_genomes/panaroo_tar
      dir_name: { default: panaroo_output }
    out: [ out ]

