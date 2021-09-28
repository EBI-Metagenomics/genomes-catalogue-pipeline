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

  gunc_decision:
    type: string
    outputSource: gunc/flag

  cluster_dir:
    type: Directory
    outputSource: return_cluster_dir/pool_directory

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
    when: $(inputs.flag.includes("complete.txt"))
    run: ../prokka-subwf.cwl
    in:
      flag: gunc/flag
      prokka_input:
        source: preparation/files
        valueFrom: $(self[0])
      outdirname: { default: prokka_output }
    out: [ faa, outdir ]

# -------- collect output ----------

  create_folder_genomes:
    doc: |
       Create folder genome for processing cluster
       That directory will have processing MGYG..fa genome inside
    # when: $(inputs.flag.basename.includes("complete.txt"))
    run: ../../../utils/return_directory.cwl
    in:
      flag: gunc/flag
      list: preparation/files
      dir_name: {default: "genome"}
    out: [ out ]

  return_cluster_dir:
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      directory_array:
        source:
          - prokka/outdir
          - create_folder_genomes/out
        pickValue: all_non_null
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ pool_directory ]


