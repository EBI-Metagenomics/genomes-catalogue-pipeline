#!/usr/bin/env cwl-runner
cwlVersion: v1.0

class: ExpressionTool

requirements:
  InlineJavascriptRequirement: {}
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1

inputs:
  dir: Directory

expression: |
  ${
    var input_array = inputs.dir.listing
    if (input_array.length > 1)
    {
      return {"files": input_array}
    }
    else
    {
      return {"file": input_array[0]}
    }
  }

outputs:
  files: File[]?
  file: File?

$namespaces:
 s: http://schema.org/
$schemas:
 - https://schema.org/version/latest/schemaorg-current-http.rdf
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - class: s:Organization
    s:name: "EMBL - European Bioinformatics Institute"
    s:url: "https://www.ebi.ac.uk"