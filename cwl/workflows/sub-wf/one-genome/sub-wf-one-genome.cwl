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
  cluster: Directory
  gunc_db_path: File
  csv: File

outputs:

  prokka_faa-s:
    type: File?
    outputSource: prokka/faa

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
      gunc_db_path: gunc_db_path
    out: [flag]

  prokka:
    when: $(inputs.flag == 'complete.txt')
    run: ../../../tools/prokka/prokka.cwl
    in:
      flag: gunc/flag
      fa_file:
        source: preparation/files
        valueFrom: $(self[0])
      outdirname: { default: prokka_output }
    out: [ faa, outdir ]

  create_cluster_genomes:
    when: $(inputs.flag == 'complete.txt')
    run: ../../../utils/return_directory.cwl
    in:
      flag: gunc/flag
      list: preparation/files
      dir_name:
        source: cluster
        valueFrom: cluster_$(self.basename)/genome
    out: [ out ]

  return_prokka_cluster_dir:
    when: $(inputs.flag == 'complete.txt')
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      flag: gunc/flag
      directory_array:
        linkMerge: merge_nested
        source:
          - prokka/outdir
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ pool_directory ]