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
  InterProScan_databases: [string, Directory]
  chunk_size_IPS: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

outputs:
  ips_result:
    type: File
    outputSource: IPS/ips_result

  eggnog_annotations:
    type: File
    outputSource: eggnog/annotations

  eggnog_seed_orthologs:
    type: File?
    outputSource: eggnog/seed_orthologs

steps:

  IPS:
    run: chunking-subwf-IPS.cwl
    in:
      faa: input_faa
      chunk_size: chunk_size_IPS
      InterProScan_databases: InterProScan_databases
    out: [ips_result]

  eggnog:
    run: chunking-subwf-eggnog.cwl
    in:
      faa_file: input_faa
      chunk_size: chunk_size_eggnog
      db_diamond: db_diamond_eggnog
      db: db_eggnog
      data_dir: data_dir_eggnog
      cpu: { default: 16 }
    out: [annotations, seed_orthologs]