cwlVersion: v1.2
class: ExpressionTool

doc: |
  Return list of files that are not correspond to input pattern.
  example:
    input: [ MGYG1.fa, MGYG2.fa, MGYG3.fa ] and pattern=MGYG2
    output: [ MGYG1.fa, MGYG3.fa ]

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
  left_files:
    type: File[]

expression: >
  ${
    var helpArray= [];
    for (var i = 0; i < inputs.list_files.length; i++) {
        if (inputs.list_files[i].nameroot.split(inputs.pattern).length == 1) {
            helpArray.push(inputs.list_files[i]);
      }}
    return { 'file_pattern' : helpArray }
  }