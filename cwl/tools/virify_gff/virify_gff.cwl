#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 1500
    coresMin: 1

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.virify-gff:v1"

baseCommand: [ virify_gff.py ]


inputs:
  virify_folder:
    type: Directory
    doc: "Virify output folder"
    inputBinding:
      prefix: --virify-folder
      position: 1
  checkv_folder:
    type: Directory?
    doc: "CheckV results folder, defaults to virify folder"
    inputBinding:
      prefix: --checkv-folder
      position: 2
  taxonomy_folder:
    type: Directory?
    doc: "File extension for checkv outputs"
    inputBinding:
      prefix: --taxonomy-folder
      position: 3
  suffix_virify:
    type: string
    doc: "File extension for taxonomy outputs"
    inputBinding:
      prefix: --suffix_virify
      position: 4
  suffix_checkv:
    type: string
    doc: "File extension for checkv outputs"
    inputBinding:
      prefix: --suffix_checkv
      position: 5
  suffix_taxonomy:
    type: string
    doc: "File extension for taxonomy outputs"
    inputBinding:
      prefix: --suffix_taxonomy
      position: 6
  sample_id:
    type: string
    doc: |
        "sample_id" to prefix output file name.
        Ignored with --rename-contigs option
    inputBinding:
      prefix: --sample-id
      position: 7
  rename_contigs:
    type: boolean
    default: False
    doc: |
        True if contigs needs renaming from ERR to ERZ
    inputBinding:
      prefix: --rename-contigs
      position: 8
  ena_contigs:
    type: boolean
    default: False
    doc: |
      "Path to ENA contig file if renaming needed"
    inputBinding:
      prefix: --ena-contigs
      position: 9

outputs:
  virify_gff:
    type: File
    outputBinding:
      glob: "*_virify.gff"
  metadata_tsv:
    type: File
    outputBinding:
      glob: "*_virify_gff_metadata.tsv"
