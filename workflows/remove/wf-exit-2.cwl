#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  many_genomes: Directory[]
  mash_folder: File[]
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]

outputs:
  mash_trees:
    type: Directory
    outputSource: return_mash_dir/out

  many_genomes_result:
    type: Directory[]
    outputSource: process_many_genomes/cluster_folder
  many_genomes_result_roary:
    type: Directory[]
    outputSource: process_many_genomes/roary_folder
  many_genomes_result_prokka:
    type:
      type: array
      items:
        type: array
        items: Directory
    outputSource: process_many_genomes/prokka_folder
  many_genomes_result_genomes:
    type: Directory[]
    outputSource: process_many_genomes/genomes_folder

  mmseqs:
    type: Directory
    outputSource: return_mmseq_dir/pool_directory

steps:

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    run: sub-wf/sub-wf-many-genomes.cwl
    scatter: cluster
    in:
      cluster: many_genomes
      mash_files: mash_folder
    out:
      - prokka_faa-s
      - cluster_folder
      - roary_folder
      - prokka_folder
      - genomes_folder

# ----------- << mash trees >> -----------
  process_mash:
    scatter: input_mash
    run: ../tools/mash2nwk/mash2nwk.cwl
    in:
      input_mash: mash_folder
    out: [mash_tree]

  return_mash_dir:
    run: ../utils/return_directory.cwl
    in:
      list: process_mash/mash_tree
      dir_name: { default: 'mash_trees' }
    out: [ out ]

# ----------- << prep mmseqs >> -----------

  flatten_many:
   run: ../utils/flatten_array.cwl
   in:
     arrayTwoDim: process_many_genomes/prokka_faa-s
   out: [array1d]

  concatenate:
    run: ../utils/concatenate.cwl
    in:
      files: flatten_many/array1d
      outputFileName: { default: 'prokka_many.fa' }
    out: [ result ]

  mmseqs:
    run: ../tools/mmseqs/mmseqs.cwl
    scatter: limit_i
    in:
      input_fasta: concatenate/result
      limit_i: mmseqs_limit_i
      limit_c: mmseqs_limit_c
    out: [ outdir ]

  return_mmseq_dir:
    run: ../utils/return_dir_of_dir.cwl
    in:
      directory_array: mmseqs/outdir
      newname: { default: "mmseqs_output" }
    out: [ pool_directory ]