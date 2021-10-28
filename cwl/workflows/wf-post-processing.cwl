#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  - per-genome annotation
  - add annotations to gffs

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

outputs:
  annotations_dir:
    type: Directory[]
    outputSource: process_folders/annotations

steps:

  choose_files:
    run: ../tools/choose_files/choose_files.cwl
    in:
      annotations: annotations
      faas: faas
      gffs: gffs
      clusters: clusters
      outdir: { default: 'out-genomes'}
    out: [ cluster_folders ]

  process_folders:
    run: sub-wf/post-processing/genome-post-processing.cwl
    scatter: files
    in:
      kegg: kegg
      files: choose_files/cluster_folders
    out:
      - annotations  # Dir
