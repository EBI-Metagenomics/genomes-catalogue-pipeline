#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Output structure:
    singleton_cluster:
        --- fna
        --- gff
        --- faa
      or null

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

  singleton_cluster:
    type: Directory?
    outputSource: cluster_folder/out

  gunc_decision:
    type: string
    outputSource: gunc/flag

  initial_fna:
    type: File?
    outputSource: get_filtered_fna/file

  prokka_faa:
    type: File?
    outputSource: prokka/faa

steps:
  preparation:
    run: ../../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [ file ]

  gunc:
    run: gunc-subwf.cwl
    in:
      input_fasta: preparation/file
      input_csv: csv
      gunc_db_path: gunc_db_path
    out: [ flag ]

  prokka:
    when: $(inputs.flag.includes("complete.txt"))
    run: ../prokka-subwf.cwl
    in:
      flag: gunc/flag
      prokka_input: preparation/file
      outdirname: { default: prokka_output }
    out:
      - faa
      - gff

  get_filtered_fna:
    when: $(inputs.flag.includes("complete.txt"))
    run: ../../../utils/get_files_from_dir.cwl
    in:
      flag: gunc/flag
      dir: cluster
    out: [ file ]

  filter_nulls:
    when: $(inputs.flag.includes("complete.txt"))
    run: ../../../utils/filter_nulls.cwl
    in:
      flag: gunc/flag
      list_files:
        - prokka/gff
        - prokka/faa
        - get_filtered_fna/file
    out: [out_files]

  cluster_folder:
    when: $(inputs.flag.includes("complete.txt"))
    run: ../../../utils/return_directory.cwl
    in:
      flag: gunc/flag
      list: filter_nulls/out_files
      dir_name:
        source: cluster
        valueFrom: $(self.basename)
    out: [ out ]