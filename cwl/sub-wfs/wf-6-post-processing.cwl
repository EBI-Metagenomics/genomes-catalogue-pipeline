#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  - kegg, cog, ..
  - ncRNA
  - add annotations to gffs
  - genome.json


requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  kegg: File
  annotations: File[]
  faas: File[]
  gffs: File[]
  clusters: File
  biom: string
  metadata: File?
  pangenome_core_genes: File[]?
  pangenome_fna: File[]?

outputs:
  annotations_cluster_dir:
    type: Directory[]
    outputSource: process_folders/annotations

  annotated_gff:
    type: File[]
    outputSource: process_folders/annotated_gff

steps:

  choose_files:
    run: ../tools/choose_files/choose_files.cwl
    in:
      annotations: annotations
      faas: faas
      gffs: gffs
      clusters: clusters
      pangenome_core_genes: pangenome_core_genes
      pangenome_fna: pangenome_fna
      outdir: { default: 'out-genomes'}
    out: [ cluster_folders ]

  process_folders:
    run: sub-wf/post-processing/genome-post-processing.cwl
    scatter: files
    in:
      kegg: kegg
      files: choose_files/cluster_folders
      biom: biom
      metadata: metadata
    out:
      - annotations  # Dir
      - annotated_gff # File
