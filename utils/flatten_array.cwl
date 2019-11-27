cwlVersion: v1.0
class: ExpressionTool
requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  arrayTwoDim:
    type:
      type: array
      items:
        type: array
        items: File
    inputBinding:
      loadContents: true

outputs:
  array1d:
    type: File[]

expression: >
  ${
    var newArray= [];
    for (var i = 0; i < inputs.arrayTwoDim.length; i++) {
      for (var k = 0; k < inputs.arrayTwoDim[i].length; k++) {
        newArray.push((inputs.arrayTwoDim[i])[k]);
      }
    }
    return { 'array1d' : newArray }
  }