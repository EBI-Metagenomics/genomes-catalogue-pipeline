#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../../../containers/python3_scripts/phylo_tree_generator.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.python3_scripts:v4"

baseCommand: [ phylo_tree_generator.py ]

inputs:
  table:
    type: File
    inputBinding:
      prefix: '--table'
      position: 1
  outname:
    type: string
    inputBinding:
      prefix: '--out'
      position: 2


outputs:
  phylo_tree_json:
    type: File
    outputBinding:
      glob: $(inputs.outname)