cwlVersion: v1.0
class: CommandLineTool

hints:
  DockerRequirement:
    dockerPull: ubuntu:latest
  ResourceRequirement:
    coresMin: 1
    ramMin: 1000

baseCommand: [ "touch" ]

inputs:
  filename:
    type: string
    inputBinding:
      position: 1

outputs:
  created_file:
    type: File
    outputBinding:
      glob: $(inputs.filename)


$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"