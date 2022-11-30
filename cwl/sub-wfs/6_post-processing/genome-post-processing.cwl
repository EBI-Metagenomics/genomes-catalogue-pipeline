#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  - kegg, cog, cazy annotations
  - ncRNA
  - sanntis  # temporarily replaced by bash step 6a
  - annotate gff

  Input:
  - Directory with files:
    - fna, faa, gff, gbk, ffn
    - pan-genome.fna (panaroo.fna), core_genes.txt [for pangenomes]
    - mash.nwk, panaroo.gene_presence_absence [for pangenomes not in use]
  - kegg db
  - ncRNA db files
  - metadata [optional]

  Output:
  - output directories:
       MGYG...
       ----- genome
               ----- fna, fna.fai, faa, gff (annotated)
               ----- kegg, cog, cazy,...
               ----- IPS, eggNOG
               ----- Sanntis
       ----- genome.json [ if metadata presented]
       ----- pan-genome
               ----- pan-genome.fna
               ----- core_genes.txt
               ----- mash.nwk
               ----- panaroo.gene_presence_absence


requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  annotations: File[]
  kegg: File
  cluster: Directory
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
  final_folder:
    type: Directory
    outputSource: create_final_folder/final_folder

  annotated_gff:
    type: File
    outputSource: annotate_gff/annotated_gff

steps:

# --------- KEGG, COG, CAZY ----------

  function_summary_stats:
    run: ../../tools/genomes-catalog-update/function_summary_stats/generate_annots.cwl
    in:
      input_dir: cluster
      output: { default: "func_summary" }
      kegg_db: kegg
      annotations: annotations
    out:
      - annotation_coverage
      - kegg_classes
      - kegg_modules
      - cazy_summary
      - cog_summary

# --------- detect ncRNA ----------

  get_list_of_files:
    run: ../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [files]

  get_fna:
    run: ../../utils/get_file_pattern.cwl
    in:
      list_files: get_list_of_files/files
      pattern:
        source: cluster
        valueFrom: "$(self.basename).fna"
    out: [file_pattern]

  ncrna:
    run: detect-ncrna-subwf.cwl
    in:
      claninfo: claninfo_ncrna
      models: models_ncrna
      fasta: get_fna/file_pattern
    out: [ cmscan_deoverlap ]

  index_fna:
    run: ../../tools/index_fasta/index_fasta.cwl
    in:
      fasta: get_fna/file_pattern
    out: [ fasta_index ]

# --------- run Sanntis ----------
  # step temporarily replaced by bash step 6a

# --------- annotate GFF ----------

  annotate_gff:
    run: ../../tools/genomes-catalog-update/annotate_gff/annotate_gff.cwl
    in:
      input_dir: cluster
      ncrna_deov: ncrna/cmscan_deoverlap
      outfile:
        source: cluster
        valueFrom: "$(self.basename).gff"
      annotations: annotations
    out: [ annotated_gff ]

# ----------- << genome.json [optional] >> -----------
  genome_json:
    when: $(Boolean(inputs.metadata))
    run: ../../tools/genomes-catalog-update/stats_json/stats_json.cwl
    in:
      metadata: metadata
      genome_annot_cov: function_summary_stats/annotation_coverage
      genome_gff: annotate_gff/annotated_gff
      files: cluster
      species_name:
        source: cluster
        valueFrom: $(self.basename)
      biom: biom
      outfilename:
        source: cluster
        valueFrom: "$(self.basename).json"
    out: [ genome_json ]

# --------- create genome final folder ----------
  create_final_folder:
    run: ../../tools/post-processing/create_final_folder/create_final_folder.cwl
    in:
      annotations: annotations
      cluster_directory: cluster
      gff: annotate_gff/annotated_gff
      kegg:
        source:
          - function_summary_stats/annotation_coverage
          - function_summary_stats/kegg_classes
          - function_summary_stats/kegg_modules
          - function_summary_stats/cazy_summary
          - function_summary_stats/cog_summary
      index: index_fna/fasta_index
      json: genome_json/genome_json
      outdir:
        source: cluster
        valueFrom: $(self.basename)
    out: [ final_folder ]