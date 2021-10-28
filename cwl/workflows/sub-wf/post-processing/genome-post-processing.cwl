#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  - kegg, cog, cazy annotations
  - annotate gff

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
    outputSource: wrap_directory/out

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

  wrap_directory:
    run: ../../../utils/return_directory.cwl
    in:
      list:
        - function_summary_stats/annotation_coverage
        - function_summary_stats/kegg_classes
        - function_summary_stats/kegg_modules
        - function_summary_stats/cazy_summary
        - function_summary_stats/cog_summary
        - annotate_gff/annotated_gff
      dir_name:
        source: files
        valueFrom: $(self.basename)
    out: [out]