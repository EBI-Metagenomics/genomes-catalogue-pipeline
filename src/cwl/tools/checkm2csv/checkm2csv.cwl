#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "checkm"

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../docker/python3_scripts/checkm2csv.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.python3_scripts:v4"

baseCommand: ["checkm2csv.py"]

inputs:
  out_checkm:
    type: File
    inputBinding:
      position: 1
      prefix: '-i'

stdout: checkm_quality.csv

outputs:
  csv: stdout

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"