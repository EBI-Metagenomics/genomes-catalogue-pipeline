#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 10000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.prokka:v1"

baseCommand: [ prokka ]

arguments:
  - valueFrom: '16'
    prefix: '--cpus'
    position: 2
  - valueFrom: 'Bacteria'
    prefix: '--kingdom'
    position: 3
  - valueFrom: $(inputs.outdirname)
    prefix: '--outdir'
    position: 4
  - valueFrom: $(inputs.fa_file.nameroot)
    prefix: '--prefix'
    position: 5
  - valueFrom: '--force'
    position: 6
  - valueFrom: $(inputs.fa_file.nameroot)
    prefix: '--locustag'
    position: 7

inputs:
  fa_file:
    type: File
    inputBinding:
      position: 1
  outdirname: string

outputs:
  gff:
    type: File
    outputBinding:
      glob: $(inputs.outdirname)/$(inputs.fa_file.nameroot).gff
  faa:
    type: File
    outputBinding:
      glob: $(inputs.outdirname)/$(inputs.fa_file.nameroot).faa
  #outdir:
  #  type: Directory
  #  outputBinding:
  #    glob: $(inputs.outdirname)
