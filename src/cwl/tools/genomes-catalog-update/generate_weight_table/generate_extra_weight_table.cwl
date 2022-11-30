#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../../docker/genomes-catalog-update/scripts/generate_extra_weight_table.py

#hints:
#  DockerRequirement:
#    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.genomes-catalog-update:v1"

baseCommand: [ generate_extra_weight_table.py ]

inputs:
  study_info:
    type: File?
    inputBinding:
      prefix: '--study-info'
      position: 1
  genome_info:
    type: File?
    inputBinding:
      prefix: '--genome-info'
      position: 2
  output:
    type: string
    inputBinding:
      prefix: '-o'
      position: 3
  input_directory:
    type: Directory
    inputBinding:
      prefix: '-d'
      position: 4

outputs:
  file_with_weights:
    type: File
    outputBinding:
      glob: $(inputs.output)

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"