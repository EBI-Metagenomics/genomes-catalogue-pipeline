#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../../docker/genomes-catalog-update/scripts/create_metadata_table.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.genome-catalog-update:v1"

baseCommand: [ create_metadata_table.py ]


inputs:
  input_dir:
    type: Directory
    inputBinding:
      prefix: '--genomes-dir'
      position: 1
  extra_weights:
    type: File
    inputBinding:
      prefix: '--extra-weight-table'
      position: 2
  checkm_results:
    type: File
    inputBinding:
      prefix: '--checkm-results'
      position: 3
  rrna:
    type: Directory
    inputBinding:
      prefix: '--rna-results'
      position: 4
  naming_table:
    type: File
    inputBinding:
      prefix: '--naming-table'
      position: 5
  clusters_split:
    type: File
    inputBinding:
      prefix: '--clusters-table'
      position: 6
  gtdb_taxonomy:
    type: File
    inputBinding:
      prefix: '--taxonomy'
      position: 7
  outfile_name:
    type: string
    inputBinding:
      prefix: '--outfile'
      position: 8
  ftp_name:
    type: string
    inputBinding:
      prefix: '--ftp-name'
      position: 9
  ftp_version:
    type: string
    inputBinding:
      prefix: '--ftp-version'
      position: 10
  geo:
    type: File
    inputBinding:
      prefix: '--geo'
      position: 11

outputs:
  metadata_table:
    type: File
    outputBinding:
      glob: $(inputs.outfile_name)
