class: CommandLineTool
cwlVersion: v1.2

requirements:
  ResourceRequirement:
    ramMin: 10000
    coresMax: 4
  InlineJavascriptRequirement: {}


hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.gunc:v4"

baseCommand: [ "gunc", "run" ]
arguments: ["-t", "4"]

inputs:
  input_fasta:
    type: File
    inputBinding:
      position: 1
      prefix: -i
  db_path:
    type: File?
    inputBinding:
      position: 2
      prefix: -r

outputs:
  gunc_tsv:
    type: File
    outputBinding:
      glob: "GUNC*maxCSS_level.tsv"

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"