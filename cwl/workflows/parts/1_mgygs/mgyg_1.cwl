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
  genomes_ena: Directory?
  ena_csv: File?
  genomes_ncbi: Directory?

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

  interproscan_databases: [string, Directory]
  chunk_size_ips: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

  cm_models: Directory

outputs:

# ------- assign_mgygs -------
  renamed_csv:
    type: File
    outputSource: assign_mgygs/renamed_csv
  naming_table:
    type: File
    outputSource: assign_mgygs/naming_table
  renamed_genomes:
    type: Directory
    outputSource: assign_mgygs/renamed_genomes


steps:

# ----------- << assign MGYGs >> -----------
  assign_mgygs:
    run: ../../../tools/genomes-catalog-update/rename_fasta/rename_fasta.cwl
    in:
      genomes: genomes_ena
      prefix: { default: "MGYG"}
      start_number: min_accession_mgyg
      max_number: max_accession_mgyg
      output_filename: { default: "names.tsv"}
      output_dirname: { default: "mgyg_genomes" }
      csv: ena_csv
    out:
      - naming_table
      - renamed_genomes
      - renamed_csv

