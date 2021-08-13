class: CommandLineTool
cwlVersion: v1.0

baseCommand: [ cat ]

hints:
  - class: DockerRequirement
    dockerPull: debian:stable-slim

inputs:
  - id: files
    type: 'File[]'
    inputBinding:
      position: 1
    streamable: true
  - id: outputFileName
    type: string

stdout: $(inputs.outputFileName)

outputs:
  - id: result
    type: stdout

requirements:
  - class: ResourceRequirement
    ramMin: 1000
    coresMax: 16
  - class: InlineJavascriptRequirement
