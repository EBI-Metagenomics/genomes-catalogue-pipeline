#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "checkm"

requirements:
  ResourceRequirement:
    ramMin: 85000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.checkm:v1"

baseCommand: ["checkm", "lineage_wf"]

arguments:
  - prefix: -t
    valueFrom: '16'
    position: 1
  - prefix: -x
    valueFrom: 'fa'
    position: 2
  - valueFrom: --tab_table
    position: 3


inputs:
  input_folder:
    type: Directory
    inputBinding:
      position: 4

  checkm_outfolder:
    type: string
    inputBinding:
      position: 5

stdout: checkm.out
stderr: checkm.err

outputs:
  stdout: stdout
  stderr: stderr

  out_folder:
    type: Directory
    outputBinding:
      glob: $(inputs.checkm_outfolder)