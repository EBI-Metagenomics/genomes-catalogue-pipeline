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
        location: ../../../docker/python3_scripts_genomes_pipeline/checkm2csv.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.python3_scripts_genomes_pipeline:v4"

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