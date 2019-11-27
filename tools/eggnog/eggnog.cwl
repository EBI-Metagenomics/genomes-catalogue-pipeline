#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: "eggNOG"

hints:
  DockerRequirement:
    dockerPull: eggnog_pipeline:latest

requirements:
  ResourceRequirement:
    ramMin: 20000
    coresMin: 16
#  InlineJavascriptRequirement: {}

baseCommand: [emapper.py]

arguments:
  - valueFrom: '16'
    prefix: '--cpu'
  - valueFrom: 'diamond'
    prefix: '-m'

inputs:
  fasta_file:
    type: File
    inputBinding:
      separate: true
      prefix: -i
    label: Input FASTA file containing query sequences

  outputname:
    type: string
    inputBinding:
      prefix: --output

outputs:
  annotations:
    type: File
    outputBinding:
      glob: $(inputs.outputname)*.annotations

  seed_orthologs:
    type: File
    outputBinding:
      glob: $(inputs.outputname)*.seed_orthologs
