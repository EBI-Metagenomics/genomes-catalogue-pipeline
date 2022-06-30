#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: ExpressionTool

requirements:
  InlineJavascriptRequirement: {}
  ResourceRequirement:
    ramMin: 200
    coresMin: 1

inputs:
  folder: Directory
  files_to_add: File[]

outputs:
  dir: Directory

expression: |
  ${
    var input_array = inputs.folder.listing;

    for (var i = 0; i < inputs.files_to_add.length; i++) {
      input_array.push(inputs.files_to_add[i]);}

    return {"dir": {
      "class": "Directory",
      "basename": inputs.folder.basename,
      "listing": input_array
    } };
  }