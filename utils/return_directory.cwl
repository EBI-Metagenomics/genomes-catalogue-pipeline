cwlVersion: v1.0
class: ExpressionTool
requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}
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