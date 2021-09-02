#!/usr/bin/env cwl-runner
cwlVersion: v1.2

class: ExpressionTool

requirements:
  InlineJavascriptRequirement: {}
  ResourceRequirement:
    ramMin: 200
    coresMin: 1

inputs:
  dir: Directory
expression: '${return {"files": inputs.dir.listing};}'
outputs:
  files: File[]