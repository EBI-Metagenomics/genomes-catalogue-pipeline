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
  genomes_folder: Directory
  input_csv: File
  skip_flag: boolean  # skip dRep for set that was already dereplicated (skip_flag=True)
  # for already dereplicated set
  sdb_dereplicated: File?
  cdb_dereplicated: File?
  mdb_dereplicated: File?

outputs:

  many_genomes:
    type: Directory[]?
    outputSource: classify_clusters/many_genomes

  one_genome:  # pickValue will not work if both are NULL
    type: Directory[]?
    outputSource: filter_nulls/out_dirs

  mash_files:
    type: File[]?
    outputSource: split_drep/split_out_mash

  split_text:
    type: File
    outputSource: split_drep/split_text

  weights_file:
    type: File?
    outputSource: generate_weights/file_with_weights

  best_cluster_reps:
    type: File?
    outputSource: drep/Sdb_csv


steps:
  generate_weights:
    when: $(!Boolean(inputs.flag))
    run: ../../tools/genomes-catalog-update/generate_weight_table/generate_extra_weight_table.cwl
    in:
      flag: skip_flag
      input_directory: genomes_folder
      output: { default: "extra_weight_table.txt" }
    out: [ file_with_weights ]

  get_genomes_list:
    when: $(!Boolean(inputs.flag))
    run: ../../utils/get_files_from_dir.cwl
    in:
      flag: skip_flag
      dir: genomes_folder
    out: [ files ]

  drep:
    when: $(!Boolean(inputs.flag))
    run: ../../tools/drep/drep.cwl
    in:
      flag: skip_flag
      genomes: get_genomes_list/files
      drep_outfolder: { default: 'drep_outfolder' }
      csv: input_csv
      extra_weights: generate_weights/file_with_weights
    out:
      - Cdb_csv
      - Mdb_csv
      - Sdb_csv

  split_drep:
    run: ../../tools/drep/split_drep.cwl
    in:
      Cdb_csv:
        source:
          - drep/Cdb_csv
          - cdb_dereplicated
        pickValue: first_non_null
      Mdb_csv:
        source:
          - drep/Mdb_csv
          - mdb_dereplicated
        pickValue: first_non_null
      Sdb_csv:
        source:
          - drep/Sdb_csv
          - sdb_dereplicated
        pickValue: first_non_null
      split_outfolder: { default: 'split_outfolder' }
    out:
      - split_out_mash
      - split_text

  classify_clusters:
    run: ../../tools/drep/classify_folders.cwl
    in:
      genomes: genomes_folder
      text_file: split_drep/split_text
    out:
      - many_genomes
      - one_genome

  filter_nulls:
    run: ../../utils/filter_nulls.cwl
    in:
      list_dirs: classify_clusters/one_genome
    out: [ out_dirs ]
