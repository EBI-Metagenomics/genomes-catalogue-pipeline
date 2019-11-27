#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 50000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: [ roary ]

arguments:
  - valueFrom: $(inputs.gffs)
    position: 1
  - valueFrom: '16'
    position: 2
    prefix: '-p'
  - valueFrom: '90'
    position: 3
    prefix: '-i'
  - valueFrom: '90'
    position: 4
    prefix: '-cd'
  - valueFrom: $(inputs.roary_outfolder)
    position: 5
    prefix: '-f'
  - valueFrom: '-v'
    position: 6
  - valueFrom: '-s'
    position: 7
  - valueFrom: '-e'
    position: 8
  - valueFrom: '-n'
    position: 9

inputs:
  gffs:
    type: File[]
  roary_outfolder: string

outputs:
  pan_genome_reference-fa:
    type: File
    outputBinding:
      glob: $(inputs.roary_outfolder)/pan_genome_reference.fa
  roary_dir:
    type: Directory
    outputBinding:
      glob: $(inputs.roary_outfolder)