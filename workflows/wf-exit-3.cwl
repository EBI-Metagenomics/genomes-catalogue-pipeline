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
  one_genome: Directory[]
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]

outputs:
  one_genome_result:
    type: Directory[]
    outputSource: process_one_genome/cluster_folder
  one_genome_result_prokka:
    type: Directory[]
    outputSource: process_one_genome/cluster_folder_prokka
  one_genome_genomes:
    type: Directory[]
    outputSource: process_one_genome/cluster_folder_genome

  mmseqs:
    type: Directory
    outputSource: return_mmseq_dir/pool_directory

steps:

# ----------- << one genome cluster processing >> -----------
  process_one_genome:
    run: sub-wf/sub-wf-one-genome.cwl
    scatter: cluster
    in:
      cluster: one_genome
    out:
      - prokka_faa-s
      - cluster_folder
      - cluster_folder_prokka
      - cluster_folder_genome

# ----------- << prep mmseqs >> -----------

  concatenate:
    run: ../utils/concatenate.cwl
    in:
      files: process_one_genome/prokka_faa-s
      outputFileName: { default: 'prokka_one.fa' }
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