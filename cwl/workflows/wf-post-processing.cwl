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
  species_representatives: File
  mmseqs_tsv: File
  ips: File
  eggnog: File
  # protein_fasta: File

outputs:
  per_genome_annotations_dir:
    type: Directory
    outputSource: generate_per_genome_annotations/per_genome_annotations

steps:

# ----------- << per genome annotation >> -----------
  generate_per_genome_annotations:
    run: ../tools/genomes-catalog-update/per_genome_annotations/make_per_genome_annotations.cwl
    in:
      ips: ips
      eggnog: eggnog
      species_representatives: species_representatives
      mmseqs: mmseqs_tsv
      cores: { default: 16 }
      outdirname: {default: per-genome-annotations }
    out: [ per_genome_annotations ]

  #function_summary_stats:
  #  run: ../tools/genomes-catalog-update/function_summary_stats/generate_annots.cwl
  #  in:
  #    ips: ips
  #    eggnog: eggnog
  #    output: { default: func_summary }
  #    protein_fasta:
  #    kegg_db: kegg
  #  out:
  #    - annotation_coverage
  #    - kegg_classes
  #    - kegg_modules
  #    - cazy_summary
  #    - cog_summary

