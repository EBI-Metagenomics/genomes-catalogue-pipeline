#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  cluster: Directory

outputs:

  prokka_faa-s:
    type: File
    outputSource: prokka/faa

  cluster_folder:
    type: Directory
    outputSource: create_cluster_folder/out
  cluster_folder_prokka:
    type: Directory
    outputSource: return_prokka_cluster_dir/pool_directory
  cluster_folder_genome:
    type: Directory
    outputSource: create_cluster_genomes/out

steps:
  preparation:
    run: ../../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [files]

  prokka:
    run: ../../../tools/prokka/prokka.cwl
    in:
      fa_file:
        source: preparation/files
        valueFrom: $(self[0])
      outdirname: { default: prokka_output }
    out: [ faa, outdir ]

  IPS:
    run: ../../../tools/IPS/InterProScan.cwl
    in:
      inputFile: prokka/faa
    out: [annotations]

  eggnog:
    run: ../../../tools/eggnog/eggnog.cwl
    in:
      fasta_file: prokka/faa
      outputname:
        source: cluster
        valueFrom: $(self.basename)
    out: [annotations, seed_orthologs]

  create_cluster_folder:
    run: ../../../utils/return_directory.cwl
    in:
      list:
        - IPS/annotations
        - eggnog/annotations
        - eggnog/seed_orthologs
      dir_name:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ out ]

  create_cluster_genomes:
    run: ../../../utils/return_directory.cwl
    in:
      list: preparation/files
      dir_name:
        source: cluster
        valueFrom: cluster_$(self.basename)/genome
    out: [ out ]

  return_prokka_cluster_dir:
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      directory_array:
        linkMerge: merge_nested
        source:
          - prokka/outdir
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ pool_directory ]