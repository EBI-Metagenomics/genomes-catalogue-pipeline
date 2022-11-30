#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  prokka_input: File
  outdirname: string

outputs:
  gff:
    type: File
    outputSource: prokka/gff
  faa:
    type: File
    outputSource: prokka/faa
  fna:
    type: File
    outputSource: prokka/fna

steps:

  change_headers:
   run: ../../utils/cut_header.cwl
   in:
     inputfile: prokka_input
   out: [created_file]

  prokka:
    run: ../../tools/prokka/prokka.cwl
    in:
      fa_file: change_headers/created_file
      outdirname: outdirname
    out: [ gff, faa, fna ]

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"