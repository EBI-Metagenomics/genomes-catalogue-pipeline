class: CommandLineTool
cwlVersion: v1.2

requirements:
  ResourceRequirement:
    ramMin: 5000
    coresMax: 4
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.detect_rrna:v2"

baseCommand: [ cmscan ]


arguments: ["--hmmonly", "--fmt", "2", "--cut_ga", "--noali", "-o", "/dev/null"]

inputs:

  cpu:
    type: int
    inputBinding:
      prefix: --cpu
      position: 1

  tblout:
    type: string
    inputBinding:
      prefix: --tblout
      position: 2

  claninfo:
    type: File
    inputBinding:
      prefix: --clanin
      position: 3

  models:
    type: File
    secondaryFiles:
      - .i1f
      - .i1i
      - .i1m
      - .i1p
    inputBinding:
      position: 10

  fasta:
    type: File
    inputBinding:
      position: 11


outputs:
  cmscan_result:
    type: File
    outputBinding:
      glob: $(inputs.tblout)

$namespaces:
 s: http://schema.org/
$schemas:
 - https://schema.org/version/latest/schemaorg-current-http.rdf
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - class: s:Organization
    s:name: "EMBL - European Bioinformatics Institute"
    s:url: "https://www.ebi.ac.uk"