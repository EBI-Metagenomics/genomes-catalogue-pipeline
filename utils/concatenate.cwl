class: CommandLineTool
cwlVersion: v1.0
$namespaces:
  s: 'http://schema.org/'

baseCommand: [ cat ]

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
