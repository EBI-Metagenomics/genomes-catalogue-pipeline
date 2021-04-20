#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: "fetch_ENA"

requirements:
  ResourceRequirement:
    ramMin: 2000
    coresMin: 4
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: ["fetch_ena.py"]

inputs:
  infile:
    type: File
    inputBinding:
      prefix: '-i'
  directory:
    type: string
    inputBinding:
      prefix: '-d'
  unzip:
    type: boolean?
    inputBinding:
      prefix: '-u'


outputs:
  downloaded_files:
    type: Directory
    outputBinding:
      glob: $(inputs.directory)
