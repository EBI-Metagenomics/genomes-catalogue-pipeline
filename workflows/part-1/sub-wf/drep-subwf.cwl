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
  genomes_folder: Directory
  input_csv: File

outputs:

  many_genomes:
    type: Directory[]
    outputSource: classify_clusters/many_genomes
  one_genome:
    type: Directory[]
    outputSource: classify_clusters/one_genome
  mash_folder:
    type: File[]
    outputSource: classify_clusters/mash_folder
  dereplicated_genomes:
    type: Directory
    outputSource: drep/dereplicated_genomes
  weights_file:
    type: File
    outputSource: generate_weights/file_with_weights


steps:
  generate_weights:
    run: ../../../tools/generate_weight_table/generate_extra_weight_table.cwl
    in:
      input_directory: genomes_folder
      output: { default: "extra_weight_table.txt" }
    out: [ file_with_weights ]

  drep:
    run: ../../../tools/drep/drep.cwl
    in:
      genomes: genomes_folder
      drep_outfolder: { default: 'drep_outfolder' }
      checkm_csv: input_csv
      extra_weights: generate_weights/file_with_weights
    out: [ out_folder, dereplicated_genomes ]

  split_drep:
    run: ../../../tools/drep/split_drep.cwl
    in:
      genomes_folder: genomes_folder
      drep_folder: drep/out_folder
      split_outfolder: { default: 'split_outfolder' }
    out: [ split_out ]

  classify_clusters:
    run: ../../../tools/drep/classify_folders.cwl
    in:
      clusters: split_drep/split_out
    out:
      - many_genomes
      - one_genome
      - mash_folder
      - stderr
      - stdout

