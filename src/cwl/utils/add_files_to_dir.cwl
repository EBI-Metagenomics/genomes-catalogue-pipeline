#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: ExpressionTool

requirements:
  InlineJavascriptRequirement: {}
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1

inputs:
  folder: Directory
  files_to_add: File[]

outputs:
  dir: Directory

expression: |
  ${
    var input_array = inputs.folder.listing;

    for (var i = 0; i < inputs.files_to_add.length; i++) {
      input_array.push(inputs.files_to_add[i]);}

    return {"dir": {
      "class": "Directory",
      "basename": inputs.folder.basename,
      "listing": input_array
    } };
  }

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"