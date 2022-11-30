#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
   Subwf gzip input gffs and put then into one folder


requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  gffs: File[]
  folder_name: string

outputs:
  gffs_folder:
    type: Directory
    outputSource: create_folder/out

steps:

  compress:
    run: ../tools/compress/pigz.cwl
    scatter: uncompressed_file
    in:
      uncompressed_file: gffs
    out: [compressed_file]

  create_folder:
    run: ../utils/return_directory.cwl
    in:
      list: compress/compressed_file
      dir_name: folder_name
    out: [out]

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"