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
        location: ../../../../docker/genomes-catalog-update/scripts/generate_stats_json.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.genome-catalog-update:v1"

baseCommand: [ generate_stats_json.py ]


inputs:
  genome_annot_cov:
    type: File
    inputBinding:
      prefix: --annot-cov
  genome_gff:
    type: File
    inputBinding:
      prefix: --gff
  metadata:
    type: File
    inputBinding:
      prefix: -m
  biom:
    type: string
    inputBinding:
      prefix: -b
  species_name:
    type: string
    inputBinding:
      prefix: -s
  outfilename:
    type: string
    inputBinding:
      prefix: -o
  files:
    type: Directory
    inputBinding:
      prefix: -i

outputs:
  genome_json:
    type: File
    outputBinding:
      glob: $(inputs.outfilename)

$namespaces:
 s: http://schema.org/
$schemas:
 - https://schema.org/version/latest/schemaorg-current-http.rdf
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - class: s:Organization
    s:name: "EMBL - European Bioinformatics Institute"
    s:url: "https://www.ebi.ac.uk"
