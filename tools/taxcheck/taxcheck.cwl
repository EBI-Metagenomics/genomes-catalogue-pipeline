#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: "taxcheck"

requirements:
  ResourceRequirement:
    ramMin: 20000
    coresMin: 4
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: ["taxcheck.sh"]

arguments:
  - prefix: -t
    valueFrom: '4'
    position: 1
  - valueFrom: $(inputs.genomes_fasta.nameroot)_$(inputs.taxcheck_outfolder)
    position: 3
    prefix: '-d'
  - valueFrom: $(inputs.genomes_fasta.nameroot)_$(inputs.taxcheck_outname)
    position: 4
    prefix: '-o'

inputs:
  genomes_fasta:
    type: File
    inputBinding:
      position: 2
      prefix: '-c'
  taxcheck_outfolder: string
  taxcheck_outname: string

outputs:
  taxcheck_folder:
    type: Directory
    outputBinding:
      glob: $(inputs.genomes_fasta.nameroot)_$(inputs.taxcheck_outfolder)
