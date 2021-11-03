#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  - kegg, cog, cazy annotations
  - annotate gff

  output directory:
    MGYG...
       ----- genome
               ----- kegg, cog, cazy,...
               ----- annotated GFF

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  kegg: File
  files: Directory

outputs:
  annotations:
    type: Directory
    outputSource: create_cluster_directory/dir_of_dir

  annotated_gff:
    type: File
    outputSource: annotate_gff/annotated_gff

steps:

# --------- KEGG, COG, CAZY ----------

  function_summary_stats:
    run: ../../../tools/genomes-catalog-update/function_summary_stats/generate_annots.cwl
    in:
      input_dir: files
      output: { default: func_summary }
      kegg_db: kegg
    out:
      - annotation_coverage
      - kegg_classes
      - kegg_modules
      - cazy_summary
      - cog_summary

# --------- annotate GFF ----------

  annotate_gff:
    run: ../../../tools/genomes-catalog-update/annotate_gff/annotate_gff.cwl
    in:
      input_dir: files
      outfile:
        source: files
        valueFrom: "annotated_$(self.basename).gff"
    out: [ annotated_gff ]

# --------- create genome folder ----------

  wrap_directory_genomes:
    run: ../../../utils/return_directory.cwl
    in:
      list:
        - function_summary_stats/annotation_coverage
        - function_summary_stats/kegg_classes
        - function_summary_stats/kegg_modules
        - function_summary_stats/cazy_summary
        - function_summary_stats/cog_summary
        - annotate_gff/annotated_gff
      dir_name: { default: 'genome'}
    out: [ out ]

# --------- create cluster folder ----------

  create_cluster_directory:
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      directory: wrap_directory_genomes/out
      newname:
        source: files
        valueFrom: $(self.basename)
    out: [ dir_of_dir ]

