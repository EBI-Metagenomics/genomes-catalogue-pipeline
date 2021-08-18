cwlVersion: v1.0
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
  list:
    type:
      - "null"
      - type: array
        items: ["null", "Directory"]

outputs:
  out: Directory[]?

expression: |
  ${
    var filtered = [];
    filtered = inputs.list.filter(function (el) { return el != null; });
    if (filtered.length == 0) {
      return {"out": "null" };}
    else {
      return {"out": filtered }
      };
  }