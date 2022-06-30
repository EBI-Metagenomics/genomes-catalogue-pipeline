#!/usr/bin/env
cwlVersion: v1.2
class: CommandLineTool

requirements:
  InlineJavascriptRequirement: {}
  ResourceRequirement:
    coresMin: 16
    ramMin: 200

hints:
  - class: DockerRequirement
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.bash:v1"

inputs:
  uncompressed_file:
    type: File
    inputBinding:
      position: 1

baseCommand: [ pigz ]
arguments: ["-p", "16", "-c"]

stdout: $(inputs.uncompressed_file.basename).gz

outputs:
  compressed_file:
    type: stdout


$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
    - name: "EMBL - European Bioinformatics Institute"
    - url: "https://www.ebi.ac.uk/"