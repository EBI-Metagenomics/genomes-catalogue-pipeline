class: CommandLineTool
cwlVersion: v1.2

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMax: 1
  InlineJavascriptRequirement: {}


hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.gunc:v4"

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
  name:
    type: string
    inputBinding:
      prefix: -n

stderr: stderr.filter.txt
stdout: stdout.filter.txt

outputs:
  complete:
    type: File?
    outputBinding:
      glob: $(inputs.name)_complete.txt

  empty:
    type: File?
    outputBinding:
      glob: $(inputs.name)_empty.txt

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"