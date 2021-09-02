#!/usr/bin/env cwl-runner
cwlVersion: v1.2.0
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  many_genomes: Directory[]?
  mash_folder: File[]?          # for many_genomes
  one_genome: Directory[]?
  mmseqs_limit_c: float         # common
  mmseqs_limit_i: float[]       # common
  csv: File
  gunc_db_path: File
  InterProScan_databases: [string, Directory]
  chunk_size_IPS: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

outputs:
  mash_folder:
    type: Directory?
    outputSource: process_many_genomes/mash_folder

  many_genomes:
    type: Directory[]?
    outputSource: process_many_genomes/many_genomes
  many_genomes_panaroo:
    type: Directory[]?
    outputSource: process_many_genomes/many_genomes_panaroo
  many_genomes_prokka:
    type:
      - 'null'
      - type: array
        items:
          type: array
          items: Directory
    outputSource: process_many_genomes/many_genomes_prokka
  many_genomes_genomes:
    type: Directory[]?
    outputSource: process_many_genomes/many_genomes_genomes

  one_genome:
    type: Directory[]?
    outputSource: process_one_genome/cluster_folder
  one_genome_prokka:
    type: Directory[]?
    outputSource: process_one_genome/cluster_folder_prokka
  one_genome_genomes:
    type: Directory[]?
    outputSource: process_one_genome/cluster_folder_genome

  mmseqs_output:
    type: Directory
    outputSource: mmseqs/mmseqs_dir

steps:

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    when: $(Boolean(inputs.input_clusters))
    run: many-genomes/wrapper-many-genomes.cwl
    in:
      input_clusters: many_genomes
      mash_folder: mash_folder
      InterProScan_databases: InterProScan_databases
      chunk_size_IPS: chunk_size_IPS
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog
    out:
      - mash_folder
      - many_genomes
      - many_genomes_panaroo
      - many_genomes_prokka
      - prokka_seqs
      - many_genomes_genomes

# ----------- << one genome cluster processing >> -----------
  process_one_genome:
    when: $(Boolean(inputs.input_cluster))
    run: one-genome/wrapper-one-genome.cwl
    in:
      input_cluster: one_genome
      csv: csv
      gunc_db_path: gunc_db_path
      InterProScan_databases: InterProScan_databases
      chunk_size_IPS: chunk_size_IPS
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog
    out:
      - prokka_faa-s
      - cluster_folder
      - cluster_folder_prokka
      - cluster_folder_genome


# ----------- << mmseqs subwf>> -----------

  mmseqs:
    run: mmseq-subwf.cwl
    in:
      prokka_many: process_many_genomes/prokka_seqs
      prokka_one: process_one_genome/prokka_faa-s
      mmseqs_limit_i: mmseqs_limit_i
      mmseqs_limit_c: mmseqs_limit_c
    out: [ mmseqs_dir ]

