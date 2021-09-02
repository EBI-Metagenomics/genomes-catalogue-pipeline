class: CommandLineTool
cwlVersion: v1.2

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMax: 1
  InlineJavascriptRequirement: {}


hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.gunc:v2"

baseCommand: [ "filter.sh" ]

inputs:
  csv:
    type: File
    inputBinding:
      prefix: -c
  gunc:
    type: File
    inputBinding:
      prefix: -g

outputs:
  complete:
    type: File?
    outputBinding:
      glob: "complete.txt"

  empty:
    type: File?
    outputBinding:
      glob: "empty.txt"
