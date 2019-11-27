#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: "split drep"

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 4
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: ["split_drep.py"]

arguments:
  - valueFrom: $(inputs.genomes_folder.location.split('file://')[1])
    prefix: '-f'
  - valueFrom: $(inputs.drep_folder.location.split('file://')[1])
    prefix: '-d'

inputs:
  genomes_folder:
    type: Directory
  drep_folder:
    type: Directory
  split_outfolder:
    type: string
    inputBinding:
      position: 3
      prefix: '-o'

outputs:
  split_out:
    type: Directory
    outputBinding:
      glob: $(inputs.split_outfolder)

