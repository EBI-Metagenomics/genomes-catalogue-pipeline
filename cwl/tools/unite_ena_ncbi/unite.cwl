#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 100
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../docker/python3_scripts/unite_ena_ncbi.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.python3:v4"

baseCommand: [ unite_ena_ncbi.py ]

inputs:
  ena_folder:
    type: Directory?
    inputBinding:
      prefix: '--ena'
      position: 1
  ncbi_folder:
    type: Directory?
    inputBinding:
      prefix: '--ncbi'
      position: 2
  ena_csv:
    type: File?
    inputBinding:
      prefix: '--ena-csv'
      position: 3
  ncbi_csv:
    type: File?
    inputBinding:
      prefix: '--ncbi-csv'
      position: 4
  outputname:
    type: string?
    inputBinding:
      prefix: '--outname'
      position: 5

outputs:
  genomes:
    type: Directory
    outputBinding:
      glob: $(inputs.outputname)
  csv:
    type: File
    outputBinding:
      glob: "$(inputs.outputname).csv"
