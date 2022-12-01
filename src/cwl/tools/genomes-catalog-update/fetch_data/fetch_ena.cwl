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