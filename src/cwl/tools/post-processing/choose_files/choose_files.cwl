#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "choose files for pos-processing"

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../../docker/python3_scripts/choose_files_post_processing.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.python3_scripts:v4"


baseCommand: ["choose_files_post_processing.py"]

inputs:
  annotations:
    type: File[]
    inputBinding:
      position: 1
      prefix: '--annotations'
  faas:
    type: File[]
    inputBinding:
      position: 2
      prefix: '--faas'
  gffs:
    type: File[]
    inputBinding:
      position: 3
      prefix: '--gffs'
  pangenome_fna:
    type: File[]?
    inputBinding:
      position: 4
      prefix: '--pangenome-fna'
  pangenome_core_genes:
    type: File[]?
    inputBinding:
      position: 5
      prefix: '--pangenome-core'
  clusters:
    type: File
    inputBinding:
      position: 6
      prefix: '--clusters'
  outdir:
    type: string
    inputBinding:
      position: 7
      prefix: '--output'

outputs:
  cluster_folders:
    type: Directory[]
    outputBinding:
      glob: "$(inputs.outdir)/*"

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"