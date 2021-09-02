#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 50000
    coresMin: 8
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.panaroo:v1"

baseCommand: [ panaroo ]

arguments:
  - valueFrom: "strict"
    position: 4
    prefix: "--clean-mode"
  - valueFrom: "--merge_paralogs"
    position: 5
  - valueFrom: "0.90"
    position: 6
    prefix: "--core_threshold"
  - valueFrom: "0.90"
    position: 7
    prefix: "-c"
  - valueFrom: "0.5"
    position: 8
    prefix: "-f"
  - valueFrom: "--no_clean_edges"

inputs:
  threads:
    type: int
    inputBinding:
      prefix: '-t'
      position: 1
  gffs:
    type: File[]
    inputBinding:
      prefix: '-i'
      position: 2
  panaroo_outfolder:
    type: string
    inputBinding:
      prefix: '-o'
      position: 3


outputs:
  pan_genome_reference-fa:
    type: File
    outputBinding:
      glob: $(inputs.panaroo_outfolder)/pan_genome_reference.fa
  panaroo_dir:
    type: Directory
    outputBinding:
      glob: $(inputs.panaroo_outfolder)
  gene_presence_absence:
    type: File
    outputBinding:
      glob: $(inputs.panaroo_outfolder)/gene_presence_absence.Rtab