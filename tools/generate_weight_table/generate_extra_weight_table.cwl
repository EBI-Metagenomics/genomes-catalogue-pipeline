#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: [ generate_extra_weight_table.py ]

inputs:
  study_info:
    type: File?
    inputBinding:
      prefix: '--study-info'
      position: 1
  genome_info:
    type: File?
    inputBinding:
      prefix: '--genome-info'
      position: 2
  output:
    type: string
    inputBinding:
      prefix: '-o'
      position: 3
  input_directory:
    type: Directory
    inputBinding:
      prefix: '-d'
      position: 4

outputs:
  file_with_weights:
    type: File
    outputBinding:
      glob: $(inputs.output)
