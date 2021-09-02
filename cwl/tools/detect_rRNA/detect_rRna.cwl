class: CommandLineTool
cwlVersion: v1.2

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMax: 1
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../docker/detect_rRNA/rna-detect.sh

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.detect_rrna:v1"

baseCommand: [ rna-detect.sh ]

inputs:
  fasta:
    type: File
    inputBinding:
      position: 1
  cm_models:
    type: Directory
    inputBinding:
      position: 2

outputs:
  out_counts:
    type: File[]
    outputBinding:
      glob: results/$(inputs.fasta.nameroot)*.out
  fasta_seq:
    type: File[]
    outputBinding:
      glob: results/$(inputs.fasta.nameroot)*.fasta

