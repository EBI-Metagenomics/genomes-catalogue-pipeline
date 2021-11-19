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
  genomes_folder: Directory
  input_csv: File
  extra_weights: File

outputs:

  cdb:
    type: File
    outputSource: drep_tar/Cdb_csv

  mdb:
    type: File
    outputSource: drep_tar/Mdb_csv

  sdb:
    type: File
    outputSource: drep_tar/Sdb_csv

steps:

  tar:
    run: ../../../utils/tar.cwl
    in:
      folder: genomes_folder
    out: [ folder_tar ]

  drep_tar:
    run: ../../../tools/drep/dRep/drep-tar.cwl
    in:
      genomes: tar/folder_tar
      drep_outfolder: { default: 'drep_outfolder' }
      csv: input_csv
      extra_weights: extra_weights
      name:
        source: genomes_folder
        valueFrom: $(self.basename)
    out:
      - Cdb_csv
      - Mdb_csv
      - Sdb_csv
