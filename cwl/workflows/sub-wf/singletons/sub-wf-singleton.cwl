#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Output structure:
    cluster
         --- genome
              --- fna
              --- fna.fai
              --- gff
              --- faa

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

  prokka_faa:
    type: File?
    outputSource: prokka/faa
  prokka_gff:
    type: File?
    outputSource: prokka/gff

  gunc_decision:
    type: string
    outputSource: gunc/flag

  cluster_dir:
    type: Directory
    outputSource: return_cluster_dir/dir_of_dir

  initial_fa:
    type: File?
    outputSource: get_filtered_fa/file

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

  index_fasta:
    when: $(inputs.flag.includes("complete.txt"))
    run: ../../../tools/index_fasta/index_fasta.cwl
    in:
      flag: gunc/flag
      fasta: preparation/file
    out: [ fasta_index ]

  get_filtered_fa:
    when: $(inputs.flag.includes("complete.txt"))
    run: ../../../utils/get_files_from_dir.cwl
    in:
      flag: gunc/flag
      dir: cluster
    out: [ file ]

# -------- collect output ----------

  create_genomes_folder:
    doc: |
       genome
         --- initial fasta
         --- initial fasta fai
         --- gff
         --- faa
    when: $(inputs.flag.includes("complete.txt"))
    run: ../../../utils/return_directory.cwl
    in:
      flag: gunc/flag
      list:
        source:
          - preparation/file  # File
          - prokka/gff         # File
          - prokka/faa         # File
          - index_fasta/fasta_index  # File
      dir_name: {default: "genome"}
    out: [ out ]

  return_cluster_dir:
    when: $(inputs.flag.includes("complete.txt"))
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      flag: gunc/flag
      directory: create_genomes_folder/out
      newname:
        source: cluster
        valueFrom: $(self.basename)
    out: [ dir_of_dir ]


