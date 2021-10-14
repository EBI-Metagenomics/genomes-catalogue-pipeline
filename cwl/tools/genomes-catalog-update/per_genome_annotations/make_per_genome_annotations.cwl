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
        location: ../../../../docker/genomes-catalog-update/scripts/make_per_genome_annotations.py

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.genome-catalog-update:v1"

baseCommand: [ make_per_genome_annotations.py ]


inputs:
  ips:
    type: File
    inputBinding:
      position: 1
      prefix: --ips
  eggnog:
    type: File
    inputBinding:
      position: 2
      prefix: --eggnog
  species_representatives:
    type: File
    inputBinding:
      position: 3
      prefix: --rep-list
  outdirname:
    type: string
    inputBinding:
      position: 4
      prefix: -o

outputs:
  per_genome_annotations:
    type: Directory
    outputBinding:
      glob: $(inputs.outdirname)

$namespaces:
 s: http://schema.org/
$schemas:
 - https://schema.org/version/latest/schemaorg-current-http.rdf
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - class: s:Organization
    s:name: "EMBL - European Bioinformatics Institute"
    s:url: "https://www.ebi.ac.uk"
