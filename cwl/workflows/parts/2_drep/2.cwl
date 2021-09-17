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
  genomes: Directory
  csv: File
  max_accession_mgyg: int
  min_accession_mgyg: int

  # skip dRep step if MAGs were already dereplicated
  skip_drep_step: string   # set "skip" for skipping

  # no gtdbtk
  skip_gtdbtk_step: string   # set "skip" for skipping

  # common input
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]
  mmseq_limit_annotation: float

  gunc_db_path: File

  gtdbtk_data: Directory?

  InterProScan_databases: [string, Directory]
  chunk_size_IPS: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

  cm_models: Directory

outputs:

# ------- drep -------
  dereplicated_genomes:                             # remove
    type: Directory?
    outputSource: drep/dereplicated_genomes
  mash_drep:                                        # remove
    type: File[]?
    outputSource: classify_clusters/mash_folder
  one_clusters:                                     # remove
    type: Directory[]?
    outputSource: classify_clusters/one_genome
  many_clusters:                                    # remove
    type: Directory[]?
    outputSource: classify_clusters/many_genomes


steps:

  generate_weights:
    when: $(inputs.flag != "skip")
    run: ../../../tools/generate_weight_table/generate_extra_weight_table.cwl
    in:
      flag: skip_drep_step
      input_directory: genomes
      output: { default: "extra_weight_table.txt" }
    out: [ file_with_weights ]

  drep:
    when: $(inputs.flag != "skip")
    run: ../../../tools/drep/drep.cwl
    in:
      flag: skip_drep_step
      genomes: genomes
      drep_outfolder: { default: 'drep_outfolder' }
      checkm_csv: csv
      extra_weights: generate_weights/file_with_weights
    out: [ Cdb_csv, Mdb_csv, dereplicated_genomes ]

  split_drep:
    when: $(inputs.flag != "skip")
    run: ../../../tools/drep/split_drep.cwl
    in:
      flag: skip_drep_step
      genomes_folder: genomes
      Cdb_csv: drep/Cdb_csv
      Mdb_csv: drep/Mdb_csv
      split_outfolder: { default: 'split_outfolder' }
    out: [ split_out ]

  classify_clusters:
    when: $(inputs.flag != "skip")
    run: ../../../tools/drep/classify_folders.cwl
    in:
      flag: skip_drep_step
      clusters: split_drep/split_out
    out:
      - many_genomes
      - one_genome
      - mash_folder
      - stderr
      - stdout
