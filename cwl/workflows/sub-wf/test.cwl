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

  skip_gtdbtk_step: boolean
  gtdbtk_data: Directory

outputs:

  many_genomes:
    type: Directory[]?
    outputSource: classify_clusters/many_genomes

  one_genome:  # pickValue will not work if both are NULL
    type: Directory[]?
    outputSource: filter_nulls/out_dirs

  mash_folder:
    type: File[]?
    outputSource: classify_clusters/mash_folder
  dereplicated_genomes:
    type: Directory?
    outputSource: drep/dereplicated_genomes
  weights_file:
    type: File?
    outputSource: generate_weights/file_with_weights


steps:
  generate_weights:
    when: $(!Boolean(inputs.flag))
    run: ../../tools/genomes-catalog-update/generate_weight_table/generate_extra_weight_table.cwl
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
      checkm_csv: input_csv
      extra_weights: generate_weights/file_with_weights
    out: [ Cdb_csv, Mdb_csv, dereplicated_genomes ]

  split_drep:
    when: $(!Boolean(inputs.flag))
    run: ../../tools/drep/split_drep.cwl
    in:
      flag: skip_flag
      genomes_folder: genomes_folder
      Cdb_csv: drep/Cdb_csv
      Mdb_csv: drep/Mdb_csv
      split_outfolder: { default: 'split_outfolder' }
      # drep_folder: drep/out_dir
    out: [ split_out ]

  classify_clusters:
    when: $(!Boolean(inputs.flag))
    run: ../../tools/drep/classify_folders.cwl
    in:
      flag: skip_flag
      clusters: split_drep/split_out
    out:
      - many_genomes
      - one_genome
      - mash_folder
      - stderr
      - stdout

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

  # ----------- << GTDB - Tk >> -----------
  gtdbtk:
    when: $(!Boolean(inputs.flag))
    run: ../../tools/gtdbtk/gtdbtk.cwl
    in:
      skip_flag: skip_gtdbtk_step
      drep_folder: drep/dereplicated_genomes
      gtdb_outfolder: { default: 'gtdb-tk_output' }
      refdata: gtdbtk_data
    out: [ gtdbtk_folder ]
