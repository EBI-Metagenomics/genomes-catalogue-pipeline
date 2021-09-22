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
        location: ../../../docker/python3_scripts/classify_folders.py

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.python3:v3"

baseCommand: [ classify_folders.py ]

stderr: stderr.txt
stdout: stdout.txt

inputs:
  genomes:
    type: Directory?
    inputBinding:
      prefix: -g
  text_file:
    type: File?
    inputBinding:
      prefix: --text-file
  clusters:
    type: Directory?
    inputBinding:
      prefix: -i

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