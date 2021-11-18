#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  - kegg, cog, cazy annotations
  - annotate gff

  Input:
  - Directory with files:
    - ips
    - eggnog
    - faa
    - gff
    - pan-genome.fna [for pangenomes]
    - core_genes.txt [for pangenomes]
  - kegg db

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
  biom: string

  claninfo_ncrna: File
  models_ncrna:
    type: File
    secondaryFiles:
      - .i1f
      - .i1i
      - .i1m
      - .i1p

  metadata: File?

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

# --------- detect ncRNA ----------

  get_fna:  ???

  ncrna:
    run: detect-ncrna-subwf.cwl
    in:
      claninfo: claninfo_ncrna
      models: models_ncrna
      fasta:
    out: cmscan_deoverlap

# --------- annotate GFF ----------

  annotate_gff:
    run: ../../../tools/genomes-catalog-update/annotate_gff/annotate_gff.cwl
    in:
      input_dir: files
      ncrna_deov: ncrna/cmscan_deoverlap
      outfile:
        source: files
        valueFrom: "annotated_$(self.basename).gff"
    out: [ annotated_gff ]

# ----------- << genome.json [optional] >> -----------
  genome_json:
    when: $(Boolean(inputs.metadata))
    run: ../../../tools/genomes-catalog-update/stats_json/stats_json.cwl
    in:
      metadata: metadata
      genome_annot_cov: function_summary_stats/annotation_coverage
      genome_gff: annotate_gff/annotated_gff
      files: files
      species_name:
        source: files
        valueFrom: $(self.basename)
      biom: biom
      outfilename:
        source: files
        valueFrom: "$(self.basename).json"
    out: [ genome_json ]

# --------- create genome folder ----------

  wrap_directory_genomes:
    run: ../../../utils/return_directory.cwl
    in:
      list:
        source:
          - function_summary_stats/annotation_coverage
          - function_summary_stats/kegg_classes
          - function_summary_stats/kegg_modules
          - function_summary_stats/cazy_summary
          - function_summary_stats/cog_summary
          - annotate_gff/annotated_gff
          - genome_json/genome_json
        pickValue: all_non_null
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

