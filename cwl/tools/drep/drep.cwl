#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: "dRep"

requirements:
  ResourceRequirement:
    ramMin: 50000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.drep:v1"


baseCommand: ["dRep", "dereplicate"]

arguments:
  - prefix: -p
    valueFrom: '16'
    position: 1
  - prefix: '-g'
    valueFrom: $(inputs.genomes.listing)
    position: 3
  - prefix: '-pa'
    position: 4
    valueFrom: '0.9'
  - prefix: '-sa'
    position: 5
    valueFrom: '0.95'
  - prefix: '-nc'
    position: 6
    valueFrom: '0.30'
  - prefix: '-cm'
    position: 7
    valueFrom: 'larger'
  - prefix: '-comp'
    position: 9
    valueFrom: '50'
  - prefix: '-con'
    position: 10
    valueFrom: '5'

inputs:
  genomes:
    type: Directory

  drep_outfolder:
    type: string
    inputBinding:
      position: 2

  checkm_csv:
    type: File
    inputBinding:
      position: 8
      prefix: '--genomeInfo'

  extra_weights:
    type: File?
    inputBinding:
      position: 11
      prefix: '-extraW'

outputs:

  out_folder:
    type: Directory
    outputBinding:
      glob: $(inputs.drep_outfolder)
  dereplicated_genomes:
    type: Directory
    outputBinding:
      glob: $(inputs.drep_outfolder)/dereplicated_genomes