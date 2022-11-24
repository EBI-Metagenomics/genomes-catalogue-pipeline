#!/usr/bin/env
cwlVersion: v1.2
class: CommandLineTool

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: get_file_pattern.py

inputs:
  list_files:
    type: File[]
    inputBinding:
      prefix: -f

  pattern:
    type: string
    inputBinding:
      prefix: -p

  outdir:
    type: string?
    inputBinding:
      prefix: -o

outputs:
  files_pattern:
    type: File[]?
    outputBinding:
      glob: "many/*"

  file_pattern:
    type: File?
    outputBinding:
      glob: "one/*"

baseCommand: ["python3", "get_file_pattern.py"]

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"