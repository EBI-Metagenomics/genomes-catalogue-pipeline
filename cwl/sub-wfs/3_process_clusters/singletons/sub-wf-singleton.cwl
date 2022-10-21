#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Output structure:
    singleton_cluster:
        --- fna
        --- gff
        --- faa
        --- gbk
        --- ffn
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

  prokka_fna:
    type: File?
    outputSource: prokka/fna

  prokka_faa:
    type: File?
    outputSource: prokka/faa

  prokka_gbk:
    type: File?
    outputSource: prokka/gbk

  prokka_ffn:
    type: File?
    outputSource: prokka/ffn

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
      - fna
      - gbk
      - ffn

  filter_nulls:
    when: $(inputs.flag.includes("complete.txt"))
    run: ../../../utils/filter_nulls.cwl
    in:
      flag: gunc/flag
      list_files:
        - prokka/gff
        - prokka/faa
        - prokka/fna
        - prokka/gbk
        - prokka/ffn
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