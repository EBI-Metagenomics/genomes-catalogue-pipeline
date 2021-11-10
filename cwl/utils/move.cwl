#!/usr/bin/env
cwlVersion: v1.2
class: CommandLineTool

requirements:
  InlineJavascriptRequirement: {}
  ResourceRequirement:
    coresMax: 1
    ramMin: 200

inputs:
  initial_file:
    type: File
    inputBinding:
      position: 1

  out_file_name:
    type: string
    inputBinding:
      position: 2

baseCommand: [ mv ]

outputs:
  renamed_file:
    type: File
    outputBinding:
      glob: $(inputs.out_file_name)

hints:
  - class: DockerRequirement
    dockerPull: alpine:3.7

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"