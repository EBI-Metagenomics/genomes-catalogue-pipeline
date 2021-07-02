class: CommandLineTool
cwlVersion: v1.0
$namespaces:
  s: 'http://schema.org/'

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMax: 1
  InlineJavascriptRequirement: {}


hints:
  DockerRequirement:
    dockerPull: "docker.io/microbiomeinformatics/gunc:v1"

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
