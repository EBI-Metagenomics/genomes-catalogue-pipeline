#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: "checkm"

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: ["checkm2csv.py"]

inputs:
  out_checkm:
    type: File
    inputBinding:
      position: 1

stdout: checkm_quality.csv

outputs:
  csv: stdout