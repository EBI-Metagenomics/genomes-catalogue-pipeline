#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: [classify_folders.py]

arguments:
  - valueFrom: $(inputs.clusters.location.split('file://')[1])
    prefix: '-i'

inputs:
  clusters:
    type: Directory

outputs:
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