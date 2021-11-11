#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../docker/python3_scripts_genomes_pipeline/classify_dereplicated.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.python3_scripts_genomes_pipeline:v4"

baseCommand: [ classify_dereplicated.py ]


inputs:
  clusters:
    type: Directory
    inputBinding:
      prefix: -i

outputs:

  one_genome:
    type: Directory[]?
    outputBinding:
      glob: "one_genome/*"
