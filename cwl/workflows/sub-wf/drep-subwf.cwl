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

  weights_file:
    type: File?
    outputSource: generate_weights/file_with_weights

  best_cluster_reps:
    type: File
    outputSource: drep/Sdb_csv


steps:
  generate_weights:
    when: $(!Boolean(inputs.flag))
    run: ../../tools/generate_weight_table/generate_extra_weight_table.cwl
    in:
      flag: skip_flag
      input_directory: genomes_folder
      output: { default: "extra_weight_table.txt" }
    out: [ file_with_weights ]

  drep:
    when: $(!Boolean(inputs.flag))
    run: ../../tools/drep/drep.cwl
    in:
      flag: skip_flag
      genomes: genomes_folder
      drep_outfolder: { default: 'drep_outfolder' }
      csv: input_csv
      extra_weights: generate_weights/file_with_weights
    out:
      - Cdb_csv
      - Mdb_csv
      - Sdb_csv

  split_drep:
    when: $(!Boolean(inputs.flag))
    run: ../../tools/drep/split_drep.cwl
    in:
      flag: skip_flag
      Cdb_csv: drep/Cdb_csv
      Mdb_csv: drep/Mdb_csv
      split_outfolder: { default: 'split_outfolder' }
    out:
      - split_out_mash
      - split_text

  classify_clusters:
    when: $(!Boolean(inputs.flag))
    run: ../../tools/drep/classify_folders.cwl
    in:
      flag: skip_flag
      genomes: genomes_folder
      text_file: split_drep/split_text
    out:
      - many_genomes
      - one_genome

  classify_dereplicated:
    when: $(Boolean(inputs.flag))
    run: ../../tools/drep/classify_dereplicated.cwl
    in:
      flag: skip_flag
      clusters: genomes_folder
    out:
      - one_genome

  filter_nulls:
    run: ../../utils/filter_nulls.cwl
    in:
      list_dirs:
        source:
          - classify_clusters/one_genome
          - classify_dereplicated/one_genome
        linkMerge: merge_flattened
        pickValue: all_non_null
    out: [ out_dirs ]
