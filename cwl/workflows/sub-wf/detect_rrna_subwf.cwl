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
  filtered_genomes: Directory
  cm_models: Directory

outputs:
  rrna_outs:
    type: Directory
    outputSource: wrap_outs/pool_directory

  rrna_fastas:
    type: Directory
    outputSource: wrap_fastas/pool_directory

steps:

  get_files:
    run: ../../utils/get_files_from_dir.cwl
    in:
      dir: filtered_genomes
    out: [files]

  detect:
    run: ../../tools/detect_rRNA/detect_rRNA.cwl
    scatter: fasta
    in:
      fasta: get_files/files
      cm_models: cm_models
    out: [out_counts, fasta_seq]

  wrap_outs:
    run: ../../utils/return_dir_of_dir.cwl
    in:
      directory_array: detect/out_counts
      newname: {default: "rRNA_outs"}
    out: [pool_directory]

  wrap_fastas:
    run: ../../utils/return_dir_of_dir.cwl
    in:
      directory_array: detect/fasta_seq
      newname: {default: "rRNA_fastas"}
    out: [pool_directory]