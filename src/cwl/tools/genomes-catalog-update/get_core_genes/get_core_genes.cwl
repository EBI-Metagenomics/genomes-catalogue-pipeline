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
        location: ../../../../../containers/genomes-catalog-update/scripts/get_core_genes.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.genomes-catalog-update:v1"

baseCommand: [ get_core_genes.py ]


inputs:
  input:
    type: File
    inputBinding:
      position: 1
      prefix: -i

  output_filename:
    type: string
    inputBinding:
      position: 2
      prefix: -o


outputs:
  core_genes:
    type: File
    outputBinding:
      glob: $(inputs.output_filename)

$namespaces:
 s: http://schema.org/
$schemas:
 - https://schema.org/version/latest/schemaorg-current-http.rdf
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - class: s:Organization
    s:name: "EMBL - European Bioinformatics Institute"
    s:url: "https://www.ebi.ac.uk"
