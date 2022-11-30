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

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"