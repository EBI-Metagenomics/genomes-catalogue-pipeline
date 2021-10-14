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
        location: ../../../docker/python3_scripts/filter_drep_genomes.py

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.python3:v3"

baseCommand: [ filter_drep_genomes.py ]

inputs:
  genomes:
    type: Directory
    inputBinding:
      prefix: '-g'
      position: 1
  clusters:
    type: File
    inputBinding:
      prefix: '--clusters'
      position: 3
  gunc_passed:
    type: File
    inputBinding:
      prefix: '--gunc'
      position: 4
  outdirname:
    type: string
    inputBinding:
      prefix: '--output'
      position: 5

outputs:
  drep_filtered_genomes:
    type: Directory
    outputBinding:
      glob: $(inputs.outdirname)
  list_drep_filtered:
    type: File
    outputBinding:
      glob: "drep-filt-list.txt"
