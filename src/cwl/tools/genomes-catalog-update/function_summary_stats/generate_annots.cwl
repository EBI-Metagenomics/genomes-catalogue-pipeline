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
        location: ../../../../../containers/genomes-catalog-update/scripts/generate_annots.py

#hints:
#  DockerRequirement:
#    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.genomes-catalog-update:v1"

baseCommand: [ generate_annots.py ]

inputs:
  input_dir:
    type: Directory
    inputBinding:
      prefix: '-i'
      position: 1
  output:
    type: string
    inputBinding:
      prefix: '-o'
      position: 3
  kegg_db:
    type: File
    inputBinding:
      prefix: '-k'
      position: 5
  annotations:
    type: File[]?
    inputBinding:
      prefix: '-a'
      position: 2

outputs:
  annotation_coverage:
    type: File
    outputBinding:
      glob: $(inputs.output)/*_annotation_coverage.tsv
  kegg_classes:
    type: File
    outputBinding:
      glob: $(inputs.output)/*_kegg_classes.tsv
  kegg_modules:
    type: File
    outputBinding:
      glob: $(inputs.output)/*_kegg_modules.tsv
  cazy_summary:
    type: File
    outputBinding:
      glob: $(inputs.output)/*_cazy_summary.tsv
  cog_summary:
    type: File
    outputBinding:
      glob: $(inputs.output)/*_cog_summary.tsv