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
  input_faa: File
  interproscan_databases: [string, Directory]
  chunk_size_ips: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]
  species_representatives: File
  mmseqs_tsv: File

outputs:
  ips_result:
    type: File
    outputSource: ips/ips_result

  eggnog_annotations:
    type: File
    outputSource: eggnog/annotations

  eggnog_seed_orthologs:
    type: File?
    outputSource: eggnog/seed_orthologs

  per_genome_annotations:
    type: File[]
    outputSource: generate_per_genome_annotations/per_genome_annotations

steps:

  ips:
    doc: |
       Subwf will run IPS-chunking if input faa file is not null
       This subwf consists of
       1. cut by chunk_size
       2. run IPS on each chunk
       3. concatenate results
    when: $(Boolean(inputs.faa))
    run: chunking-subwf-IPS.cwl
    in:
      faa: input_faa
      chunk_size: chunk_size_ips
      interproscan_databases: interproscan_databases
    out: [ips_result]

  eggnog:
    doc: |
       Subwf will run eggnog-chunking if input faa file is not null
       This subwf consists of
       1. cut by chunk_size
       2. run eggnog on each chunk
       3. concatenate results
    when: $(Boolean(inputs.faa_file))
    run: chunking-subwf-eggnog.cwl
    in:
      faa_file: input_faa
      chunk_size: chunk_size_eggnog
      db_diamond: db_diamond_eggnog
      db: db_eggnog
      data_dir: data_dir_eggnog
      cpu: { default: 16 }
    out: [annotations, seed_orthologs]

  # ----------- << per genome annotation >> -----------
  generate_per_genome_annotations:
    run: ../../tools/genomes-catalog-update/per_genome_annotations/make_per_genome_annotations.cwl
    in:
      ips: ips/ips_result
      eggnog: eggnog/annotations
      species_representatives: species_representatives
      mmseqs: mmseqs_tsv
      cores: { default: 16 }
      outdirname: {default: per-genome-annotations }
    out: [ per_genome_annotations ]  # File[]