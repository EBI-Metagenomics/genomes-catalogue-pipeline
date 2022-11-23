#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 10000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: [ run_macse.sh ]

arguments:
  - valueFrom: 'translateNT2AA'
    prefix: '-prog'
    position: 1
  - valueFrom: '11'
    prefix: '-gc_def'
    position: 3

inputs:
  fa_file:
    type: File
    inputBinding:
      position: 2
      prefix: '-seq'
  faa_file:
    type: string
    inputBinding:
      position: 4
      prefix: '-out_AA'

outputs:
  converted_faa:
    type: File
    outputBinding:
      glob: $(inputs.faa_file)
