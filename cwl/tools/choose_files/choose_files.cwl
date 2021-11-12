#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "choose files for pos-processing"

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../docker/python3_scripts/choose_files_post_processing.py

#hints:
#  DockerRequirement:
#    dockerPull: "microbiomeinformatics/genomes-pipeline.python3:v3"

baseCommand: ["choose_files_post_processing.py"]

inputs:
  annotations:
    type: File[]
    inputBinding:
      position: 1
      prefix: '--annotations'
  faas:
    type: File[]
    inputBinding:
      position: 2
      prefix: '--faas'
  gffs:
    type: File[]
    inputBinding:
      position: 3
      prefix: '--gffs'
  clusters:
    type: File
    inputBinding:
      position: 4
      prefix: '--clusters'
  outdir:
    type: string
    inputBinding:
      position: 5
      prefix: '--output'

outputs:
  cluster_folders:
    type: Directory[]
    outputBinding:
      glob: "$(inputs.outdir)/*"