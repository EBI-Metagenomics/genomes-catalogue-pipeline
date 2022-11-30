#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  input_fasta: File
  input_csv: File
  gunc_db_path: File

outputs:
  tsv:
    type: File
    outputSource: gunc/gunc_tsv
  flag:
    type: string
    outputSource: return_name/name


steps:
  gunc:
    run: ../../../tools/GUNC/gunc.cwl
    in:
      input_fasta: input_fasta
      db_path: gunc_db_path
    out: [ gunc_tsv ]

  filter:
    run: ../../../tools/GUNC/filter_gunc.cwl
    in:
      csv: input_csv
      gunc: gunc/gunc_tsv
      name:
        source: input_fasta
        valueFrom: $(self.nameroot)
    out:
      - complete
      - empty

  return_name:
    run: ../../../tools/GUNC/return_name.cwl
    in:
      input:
        source:
          - filter/complete
          - filter/empty
        pickValue: first_non_null
    out: [name]

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"