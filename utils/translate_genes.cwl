class: CommandLineTool
cwlVersion: v1.0
$namespaces:
  s: 'http://schema.org/'

baseCommand: [ translate_genes.py ]

inputs:
  fa_file:
    type: File
    inputBinding:
      position: 1
      prefix: -i

  faa_file:
    type: string
    inputBinding:
      position: 2
      prefix: -o

outputs:
  converted_faa:
    type: File
    outputBinding:
      glob: $(inputs.faa_file)

requirements:
  - class: ResourceRequirement
    ramMin: 1000
    coresMax: 16
  - class: InlineJavascriptRequirement
