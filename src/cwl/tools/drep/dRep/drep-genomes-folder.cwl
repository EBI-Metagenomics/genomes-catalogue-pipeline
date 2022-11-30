#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: "dRep"

requirements:
  ResourceRequirement:
    ramMin: 50000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.drep:v2"

baseCommand: ["dRep", "dereplicate"]

arguments:
  - prefix: '-g'
    valueFrom: $(inputs.genomes.listing)
    position: 3
  - prefix: -p
    valueFrom: '16'
    position: 1
  - prefix: '-pa'
    position: 4
    valueFrom: '0.9'
  - prefix: '-sa'
    position: 5
    valueFrom: '0.95'
  - prefix: '-nc'
    position: 6
    valueFrom: '0.30'
  - prefix: '-cm'
    position: 7
    valueFrom: 'larger'
  - prefix: '-comp'
    position: 9
    valueFrom: '50'
  - prefix: '-con'
    position: 10
    valueFrom: '5'

inputs:
  genomes: Directory

  drep_outfolder:
    type: string
    inputBinding:
      position: 2

  csv:
    type: File
    inputBinding:
      position: 8
      prefix: '--genomeInfo'

  extra_weights:
    type: File?
    inputBinding:
      position: 11
      prefix: '-extraW'


outputs:

  Cdb_csv:
    type: File
    outputBinding:
      glob: $(inputs.drep_outfolder)/data_tables/Cdb.csv

  Mdb_csv:
    type: File
    outputBinding:
      glob: $(inputs.drep_outfolder)/data_tables/Mdb.csv

  Sdb_csv:
    type: File
    outputBinding:
      glob: $(inputs.drep_outfolder)/data_tables/Sdb.csv

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"