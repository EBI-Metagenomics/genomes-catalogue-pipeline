cwlVersion: v1.2
class: ExpressionTool

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1

inputs:
  input: File

outputs:
  name: string

expression: |
  ${
    return {
        "name": inputs.input.basename
    }
  }