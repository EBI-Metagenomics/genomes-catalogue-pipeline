cwlVersion: v1.2
class: ExpressionTool

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}
  ResourceRequirement:
    ramMin: 200
    coresMin: 1

inputs:
  list: File[]
  dir_name: string

outputs:
  out: Directory

expression: |
  ${
    return {"out": {
      "class": "Directory",
      "basename": inputs.dir_name,
      "listing": inputs.list
    } };
  }