#!/usr/bin/env cwl-runner
cwlVersion: v1.2.0-dev2
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  many_genomes: Directory[]?
  mash_folder: File[]?          # for many_genomes
  one_genome: Directory[]?
  mmseqs_limit_c: float         # common
  mmseqs_limit_i: float[]       # common

outputs:
  mash_folder:
    type: Directory?
    outputSource: process_many_genomes/mash_folder

  many_genomes:
    type: Directory[]?
    outputSource: process_many_genomes/cluster_folder
  many_genomes_panaroo:
    type: Directory[]?
    outputSource: process_many_genomes/panaroo_folder
  many_genomes_prokka:
    type:
      - 'null'
      - type: array
        items:
          type: array
          items: Directory
    outputSource: process_many_genomes/prokka_folder
  many_genomes_genomes:
    type: Directory[]?
    outputSource: process_many_genomes/genomes_folder


steps:

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    when: $(inputs.marker != 'null')
    run: sub-wf/sub-wf-many-genomes.cwl
    scatter: cluster
    in:
      marker: many_genomes
      cluster: many_genomes
      mash_files: mash_folder
    out:
      - prokka_faa-s
      - cluster_folder
      - panaroo_folder
      - prokka_folder
      - genomes_folder
      - mash_folder

