#!/usr/bin/env cwl-runner
cwlVersion: v1.2.0-dev2
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  cluster: Directory
  csv: File

outputs:

  prokka_faa-s:
    type: File?
    outputSource: prokka/faa

  cluster_folder:
    type: Directory?
    outputSource: create_cluster_folder/out
  cluster_folder_prokka:
    type: Directory?
    outputSource: return_prokka_cluster_dir/pool_directory
  cluster_folder_genome:
    type: Directory?
    outputSource: create_cluster_genomes/out

steps:
  preparation:
    run: ../../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [files]

  gunc:
    run: gunc-subwf.cwl
    in:
      input_fasta:
        source: preparation/files
        valueFrom: $(self[0])
      input_csv: csv
    out:
      - complete-flag
      - empty-flag

  prokka:
    when: $(Boolean(inputs.flag))
    run: ../../../tools/prokka/prokka.cwl
    in:
      flag: gunc/complete-flag
      fa_file:
        source: preparation/files
        valueFrom: $(self[0])
      outdirname: { default: prokka_output }
    out: [ faa, outdir ]

  IPS:
    when: $(Boolean(inputs.flag))
    run: ../../../tools/IPS/InterProScan.cwl
    in:
      flag: gunc/complete-flag
      inputFile: prokka/faa
    out: [annotations]

  eggnog:
    when: $(Boolean(inputs.flag))
    run: ../../../tools/eggnog/eggnog.cwl
    in:
      flag: gunc/complete-flag
      fasta_file: prokka/faa
      outputname:
        source: cluster
        valueFrom: $(self.basename)
    out: [annotations, seed_orthologs]

  create_cluster_folder:
    when: $(Boolean(inputs.flag))
    run: ../../../utils/return_directory.cwl
    in:
      flag: gunc/complete-flag
      list:
        - IPS/annotations
        - eggnog/annotations
        - eggnog/seed_orthologs
      dir_name:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ out ]

  create_cluster_genomes:
    when: $(Boolean(inputs.flag))
    run: ../../../utils/return_directory.cwl
    in:
      flag: gunc/complete-flag
      list: preparation/files
      dir_name:
        source: cluster
        valueFrom: cluster_$(self.basename)/genome
    out: [ out ]

  return_prokka_cluster_dir:
    when: $(Boolean(inputs.flag))
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      flag: gunc/complete-flag
      directory_array:
        linkMerge: merge_nested
        source:
          - prokka/outdir
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ pool_directory ]