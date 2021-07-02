#!/usr/bin/env cwl-runner
cwlVersion: v1.0
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
        location: ../../../docker/python3_scripts/classify_folders.py

hints:
  DockerRequirement:
    dockerPull: "docker.io/microbiomeinformatics/genomes-pipeline.python3:v1"

baseCommand: [ classify_folders.py ]

arguments:
  - valueFrom: $(inputs.clusters.location.split('file://')[1])
    prefix: '-i'

stderr: stderr.txt
stdout: stdout.txt

inputs:
  clusters:
    type: Directory

outputs:
  stderr: stderr
  stdout: stdout

  many_genomes:
    type: Directory[]?
    outputBinding:
      glob: "many_genomes/*"
  one_genome:
    type: Directory[]?
    outputBinding:
      glob: "one_genome/*"
  mash_folder:
    type: File[]?
    outputBinding:
      glob: "mash_folder/*"