#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "fetch_ENA"

requirements:
  ResourceRequirement:
    ramMin: 2000
    coresMin: 4
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../../docker/genomes-catalog-update/scripts/fetch_ena.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.genomes-catalog-update:v1"

baseCommand: ["fetch_ena.py"]

inputs:
  infile:
    type: File
    inputBinding:
      prefix: '-i'
  directory:
    type: string
    inputBinding:
      prefix: '-d'
  unzip:
    type: boolean?
    inputBinding:
      prefix: '-u'


outputs:
  downloaded_files:
    type: Directory?
    outputBinding:
      glob: $(inputs.directory)
  stats_file:
    type: File?
    outputBinding:
      glob: $(inputs.directory)/*.txt

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"