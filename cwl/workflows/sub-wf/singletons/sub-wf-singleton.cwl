#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Output structure:
    cluster
         --- genome
              --- fna
              --- gff

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

  gunc_decision:
    type: string
    outputSource: gunc/flag

  cluster_dir:
    type: Directory
    outputSource: return_cluster_dir/dir_of_dir

steps:
  preparation:
    run: ../../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [ files ]

  gunc:
    run: gunc-subwf.cwl
    in:
      input_fasta:
        source: preparation/files
        valueFrom: $(self[0])
      input_csv: csv
      gunc_db_path: gunc_db_path
    out: [ flag ]

  prokka:
    when: $(inputs.flag.includes("complete.txt"))
    run: ../prokka-subwf.cwl
    in:
      flag: gunc/flag
      prokka_input:
        source: preparation/files
        valueFrom: $(self[0])
      outdirname: { default: prokka_output }
    out:
      - faa
      - gff

# -------- collect output ----------

  create_genomes_folder:
    doc: |
       genome
         --- initial fasta
         --- gff
    when: $(inputs.flag.basename.includes("complete.txt"))
    run: ../../../utils/return_directory.cwl
    in:
      flag: gunc/flag
      list:
        source:
          - preparation/files  # File[]
          - prokka/gff         # File
        linkMerge: merge_flattened
      dir_name: {default: "genome"}
    out: [ out ]

  return_cluster_dir:
    when: $(inputs.flag.basename.includes("complete.txt"))
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      directory: create_genomes_folder/out
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ dir_of_dir ]


