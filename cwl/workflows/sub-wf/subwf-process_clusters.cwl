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
  many_genomes: Directory[]?
  mash_folder: File[]?          # for many_genomes
  one_genome: Directory[]?
  mmseqs_limit_c: float         # common
  mmseqs_limit_i: float[]       # common
  mmseq_limit_annotation: float
  csv: File
  gunc_db_path: File
  interproscan_databases: [string, Directory]
  chunk_size_ips: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

outputs:
  mash_folder:
    type: Directory?
    outputSource: return_mash_dir/out

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
  one_genome_genomes_gunc_completed:
    type: File
    outputSource: process_one_genome/gunc_completed
  one_genome_genomes_gunc_failed:
    type: File
    outputSource: process_one_genome/gunc_failed

  mmseqs_output:
    type: Directory?
    outputSource: mmseqs/mmseqs_dir
  mmseqs_output_annotation:
    type: Directory?
    outputSource: mmseqs/mmseqs_dir_annotation
  cluster_representatives:
    type: File?
    outputSource: mmseqs/cluster_reps

steps:

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    when: $(Boolean(inputs.input_clusters))
    run: many-genomes/wrapper-many-genomes.cwl
    in:
      input_clusters: many_genomes
      mash_folder: mash_folder
      interproscan_databases: interproscan_databases
      chunk_size_ips: chunk_size_ips
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

# ----------- << mash trees >> -----------
  process_mash:
    scatter: input_mash
    run: ../../tools/mash2nwk/mash2nwk.cwl
    in:
      input_mash: mash_folder
    out: [mash_tree]

  return_mash_dir:
    run: ../../utils/return_directory.cwl
    in:
      list: process_mash/mash_tree
      dir_name: { default: 'mash_trees' }
    out: [ out ]

# ----------- << one genome cluster processing >> -----------
  process_one_genome:
    when: $(Boolean(inputs.input_cluster))
    run: one-genome/wrapper-one-genome.cwl
    in:
      input_cluster: one_genome
      csv: csv
      gunc_db_path: gunc_db_path
      interproscan_databases: interproscan_databases
      chunk_size_ips: chunk_size_ips
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog
    out:
      - prokka_faa-s
      - cluster_folder
      - gunc_completed
      - gunc_failed

# ----------- << mmseqs subwf>> -----------

  mmseqs:
    run: mmseq-subwf.cwl
    in:
      prokka_many: process_many_genomes/prokka_seqs
      prokka_one: process_one_genome/prokka_faa-s
      mmseqs_limit_i: mmseqs_limit_i
      mmseqs_limit_c: mmseqs_limit_c
      mmseq_limit_annotation: mmseq_limit_annotation
    out: [ mmseqs_dir, mmseqs_dir_annotation, cluster_reps ]

