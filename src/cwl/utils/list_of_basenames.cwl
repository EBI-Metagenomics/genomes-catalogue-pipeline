#!/usr/bin/env cwl-runner

cwlVersion: v1.2
class: CommandLineTool

requirements:
  MultipleInputFeatureRequirement: {}

baseCommand: basename

inputs:
  files:
    type: File[]
    inputBinding:
      position: 1
      prefix: -a
  name: string

stdout: $(inputs.name)

outputs:
  list: stdout

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"