#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 250000
    coresMin: 32
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: [ bash, /hps/nobackup2/production/metagenomics/databases/human-gut_resource/cwl_pipeline/genomes-pipeline/tools/mmseqs/test.sh ]

arguments:
  - valueFrom: '32'
    prefix: -t
  - valueFrom: mmseqs_$(inputs.limit_i)_outdir
    prefix: -o

inputs:
  input_fasta:
    type: File
    inputBinding:
      prefix: '-f'

  limit_i:
    type: float
    inputBinding:
      prefix: -i
  limit_c:
    type: float
    inputBinding:
      prefix: -c
  db:
    type: File
    inputBinding:
      prefix: -d

outputs:
  outdir:
    type: Directory
    outputBinding:
      glob: mmseqs_$(inputs.limit_i)_outdir*
      #mmseqs_$(inputs.limit_i)_outdir