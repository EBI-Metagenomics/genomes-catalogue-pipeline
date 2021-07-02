#!/usr/bin/env cwl-runner
cwlVersion: v1.0
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
        location: ../../../docker/genome-catalog-update/scripts/fetch_ncbi.py

hints:
  DockerRequirement:
    dockerPull: "docker.io/microbiomeinformatics/genomes-pipeline.genome-catalog-update:v1"

baseCommand: ["fetch_ncbi.py"]

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
