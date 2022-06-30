cwlVersion: v1.2
class: ExpressionTool

doc: |
  Return file that's nameroot has input pattern. In case of many files - would be returned first
  example:
    input: [ MGYG1.fa, MGYG2.fa, MGYG3.fa ] and pattern=MGYG2
    output: MGYG2.fa

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
    type:
      - File
      - File[]

expression: >
  ${
    var helpArray= [];
    for (var i = 0; i < inputs.list_files.length; i++) {
        if (inputs.list_files[i].basename.split(inputs.pattern).length > 1) {
            helpArray.push(inputs.list_files[i]);
      }}
    if (helpArray.length == 1) {
      return {'file_pattern' : helpArray[0]}}
    else {
      return { 'file_pattern' : helpArray }}
  }