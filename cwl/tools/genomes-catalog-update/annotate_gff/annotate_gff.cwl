class: CommandLineTool
cwlVersion: v1.2

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMax: 1
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../../docker/genomes-catalog-update/scripts/annot_gff.py

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.genome-catalog-update:v1"

baseCommand: [ annot_gff.py ]


inputs:
  gff:
    type: File
    inputBinding:
      position: 1
      prefix: -g

  eggnog:
    type: File
    inputBinding:
      position: 2
      prefix: -e

  ips:
    type: File
    inputBinding:
      position: 3
      prefix: -i

  outfile:
    type: string
    inputBinding:
      position: 4
      prefix: -o


outputs:
  annotated_gff:
    type: File
    outputBinding:
      glob: $(inputs.outfile)

$namespaces:
 s: http://schema.org/
$schemas:
 - https://schema.org/version/latest/schemaorg-current-http.rdf
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - class: s:Organization
    s:name: "EMBL - European Bioinformatics Institute"
    s:url: "https://www.ebi.ac.uk"
