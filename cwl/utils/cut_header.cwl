cwlVersion: v1.2
class: CommandLineTool
requirements:
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: cut_header.sh

hints:
  DockerRequirement:
    dockerPull: debian:stable-slim
  ResourceRequirement:
    coresMin: 1
    ramMin: 1000

baseCommand: [sh]

inputs:
  script:
    type: string?
    default: cut_header.sh
    inputBinding:
      position: 1
  inputfile:
    type: File
    inputBinding:
      position: 2
      prefix: -i

stdout: $(inputs.inputfile.nameroot)$(inputs.inputfile.nameext)
stderr: stderr.txt

outputs:
  created_file: stdout


$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"