class: CommandLineTool
cwlVersion: v1.2

baseCommand: [ cat ]

hints:
  - class: DockerRequirement
    dockerPull: debian:stable-slim

inputs:
  files:
    type: File[]?
    inputBinding:
      position: 1
    streamable: true
  outputFileName: string

stdout: $(inputs.outputFileName)

outputs:
  - id: result
    type: stdout

requirements:
  - class: ResourceRequirement
    ramMin: 1000
    coresMax: 16
  - class: InlineJavascriptRequirement
