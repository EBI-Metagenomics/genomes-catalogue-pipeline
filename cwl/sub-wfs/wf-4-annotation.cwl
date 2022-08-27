#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  - process singleton and pan-genome clusters
  - IPS + eggnog
  - filter drep genomes + filtered by GUNC
  - detect rRNA

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}

inputs:
  mmseqs_faa: File
  mmseqs_tsv: File
  all_reps_filtered: File
  all_fnas: File[]?
  all_fnas_dir: Directory?

  interproscan_databases: [string, Directory]
  chunk_size_ips: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

  cm_models: Directory

steps:
# ----------- << functional annotation >> ------
  functional_annotation:
    run: 4_annotation/functional_annotation.cwl
    in:
      input_faa: mmseqs_faa
      interproscan_databases: interproscan_databases
      chunk_size_ips: chunk_size_ips
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog
      species_representatives: all_reps_filtered
      mmseqs_tsv: mmseqs_tsv
    out:
      - ips_result
      - eggnog_annotations
      - per_genome_annotations

# ---------- << detect rRNA >> ---------
  detect_rrna:
    run: 4_annotation/detect_rrna_subwf.cwl
    in:
      filtered_genomes: all_fnas
      filtered_genomes_folder: all_fnas_dir
      cm_models: cm_models
    out: [rrna_outs, rrna_fastas]

outputs:

# ------- functional annotation ----------
  ips_eggnog_annotations:
    type: File[]
    outputSource: functional_annotation/per_genome_annotations
  ips_tsv:
    type: File
    outputSource: functional_annotation/ips_result
  eggnog_tsv:
    type: File
    outputSource: functional_annotation/eggnog_annotations

# ---------- rRNA -------------
  rrna_out:
    type: Directory
    outputSource: detect_rrna/rrna_outs

  rrna_fasta:
    type: Directory
    outputSource: detect_rrna/rrna_fastas

$namespaces:
 s: http://schema.org/
$schemas:
 - https://schema.org/version/latest/schemaorg-current-http.rdf
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - class: s:Organization
    s:name: "EMBL - European Bioinformatics Institute"
    s:url: "https://www.ebi.ac.uk"