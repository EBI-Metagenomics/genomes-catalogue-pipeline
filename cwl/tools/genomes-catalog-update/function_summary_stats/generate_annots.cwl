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
        location: ../../../../docker/genomes-catalog-update/scripts/generate_annots.py

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.genome-catalog-update:v1"

baseCommand: [ generate_annots.py ]

inputs:
  ips:
    type: File
    inputBinding:
      prefix: '-i'
      position: 1
  eggnog:
    type: File
    inputBinding:
      prefix: '-e'
      position: 2
  output:
    type: string
    inputBinding:
      prefix: '-o'
      position: 3
  protein_fasta:
    type: Directory
    inputBinding:
      prefix: '-f'
      position: 4
  kegg_db:
    type: Directory
    inputBinding:
      prefix: '-k'
      position: 5

outputs:
  annotation_coverage:
    type: File
    outputBinding:
      glob: $(inputs.output)/annotation_coverage.tsv
  kegg_classes:
    type: File
    outputBinding:
      glob: $(inputs.output)/kegg_classes.tsv
  kegg_modules:
    type: File
    outputBinding:
      glob: $(inputs.output)/kegg_modules.tsv
  cazy_summary:
    type: File
    outputBinding:
      glob: $(inputs.output)/cazy_summary.tsv
  cog_summary:
    type: File
    outputBinding:
      glob: $(inputs.output)/cog_summary.tsv