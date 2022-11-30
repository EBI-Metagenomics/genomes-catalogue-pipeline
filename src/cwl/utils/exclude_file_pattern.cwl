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
    ramMin: 1000
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
    return { 'left_files' : helpArray }
  }

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"