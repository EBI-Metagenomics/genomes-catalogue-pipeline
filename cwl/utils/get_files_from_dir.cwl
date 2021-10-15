#!/usr/bin/env cwl-runner
cwlVersion: v1.0

class: ExpressionTool

requirements:
  InlineJavascriptRequirement: {}
  ResourceRequirement:
    ramMin: 200
    coresMin: 1

inputs:
  dir: Directory

expression: |
  ${
    var input_array = inputs.dir.listing
    if (input_array.length > 1)
    {
      return {"files": input_array}
    }
    else
    {
      return {"file": input_array[0]}
    }
  }

outputs:
  files: File[]?
  file: File?