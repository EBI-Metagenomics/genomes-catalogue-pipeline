class: CommandLineTool
cwlVersion: v1.2

baseCommand: [ cat ]

#hints:
#  - class: DockerRequirement
#    dockerPull: debian:stable-slim

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

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"