#!/usr/bin/env cwl-runner

cwlVersion: v1.2
class: CommandLineTool

requirements:
  MultipleInputFeatureRequirement: {}

baseCommand: basename

inputs:
  files:
    type: File[]
    inputBinding:
      position: 1
      prefix: -a
  name: string

stdout: $(inputs.name)

outputs:
  list: stdout