#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: "checkm"

requirements:
  ResourceRequirement:
    ramMin: 85000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: ["checkm", "lineage_wf"]

arguments:
  - prefix: -t
    valueFrom: '16'
    position: 1
  - prefix: -x
    valueFrom: 'fa'
    position: 2
  - prefix: --tab_table
    position: 5


inputs:
  input_folder:
    type: string
    inputBinding:
      position: 3

  checkm_outfolder:
    type: string
    inputBinding:
      position: 4

stdout: checkm.out

outputs:
  stdout: stdout

  out_folder:
    type: Directory
    outputBinding:
      glob: $(inputs.checkm_outfolder)