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
  genomes_folder: Directory
  input_csv: File
  extra_weights: File

outputs:

  cdb:
    type: File
    outputSource: drep/Cdb_csv

  mdb:
    type: File
    outputSource: drep/Mdb_csv

  sdb:
    type: File
    outputSource: drep/Sdb_csv


steps:

  drep:
    run: ../../tools/drep/dRep/drep-genomes-folder.cwl
    in:
      genomes: genomes_folder
      drep_outfolder: { default: 'drep_outfolder' }
      csv: input_csv
      extra_weights: extra_weights
    out:
      - Cdb_csv
      - Mdb_csv
      - Sdb_csv

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"