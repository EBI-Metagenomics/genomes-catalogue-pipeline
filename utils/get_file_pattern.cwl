cwlVersion: v1.0
class: ExpressionTool

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}
  ResourceRequirement:
    ramMin: 100
    coresMin: 1

inputs:
  list_files: File[]
  pattern: string

outputs:
  file_pattern:
    type: File

expression: >
  ${
    var helpArray= [];
    for (var i = 0; i < inputs.list_files.length; i++) {
        if (inputs.list_files[i].nameroot.split(inputs.pattern).length > 1) {
            helpArray.push(inputs.list_files[i]);
      }}
    return { 'file_pattern' : helpArray[0] }
  }