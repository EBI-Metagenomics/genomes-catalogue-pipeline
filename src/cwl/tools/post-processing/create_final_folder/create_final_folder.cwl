#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "create final folder with genome and pan-genome"

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../../docker/python3_scripts/create_final_folder.py

#hints:
#  DockerRequirement:
#    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.python3_scripts:v4"

baseCommand: ["create_final_folder.py"]

inputs:
  annotations:
    type: File[]?
    inputBinding:
      position: 1
      prefix: '-a'
  cluster_directory:
    type: Directory
    inputBinding:
      position: 2
      prefix: '-i'
  gff:
    type: File
    inputBinding:
      position: 3
      prefix: '-g'
  kegg:
    type: File[]
    inputBinding:
      position: 4
      prefix: '-k'
  index:
    type: File
    inputBinding:
      position: 5
      prefix: '--index'
  json:
    type: File?
    inputBinding:
      position: 6
      prefix: '-j'
  outdir:
    type: string
    inputBinding:
      position: 7
      prefix: '-n'

outputs:
  final_folder:
    type: Directory
    outputBinding:
      glob: "$(inputs.outdir)"

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"