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
  download_from: string  # ENA or NCBI
  infile: File            # file containing a list of GenBank accessions, one accession per line
  directory_name: string  # directory name to download files to
  unzip: boolean?
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]


outputs:
  checkm_csv:
    type: File
    outputSource: wf-1/checkm_csv
  gtdbtk:
    type: Directory
    outputSource: wf-1/gtdbtk
  taxcheck_dir:
    type: Directory
    outputSource: wf-1/taxcheck_dir

  mash_folder:
    type: Directory?
    outputSource: wf-2/mash_folder

  many_genomes:
    type: Directory[]?
    outputSource: wf-2/many_genomes
  many_genomes_roary:
    type: Directory[]?
    outputSource: wf-2/many_genomes_roary
  many_genomes_prokka:
    type:
      - 'null'
      - type: array
        items:
          type: array
          items: Directory
    outputSource: wf-2/many_genomes_prokka
  many_genomes_genomes:
    type: Directory[]?
    outputSource: wf-2/many_genomes_genomes

  one_genome:
    type: Directory[]?
    outputSource: wf-2/one_genome
  one_genome_prokka:
    type: Directory[]?
    outputSource: wf-2/one_genome_prokka
  one_genome_genomes:
    type: Directory[]?
    outputSource: wf-2/one_genome_genomes

  mmseqs:
    type: Directory
    outputSource: wf-2/mmseqs


steps:
# ----------- << download data >> -----------
  download:
    run: sub-wf/fetch_data.cwl
    in:
      download_from: download_from
      infile: infile
      directory_name: directory_name
      unzip: unzip
    out: [ downloaded_folder ]

# ---------- first part
  wf-1:
    run: wf-1.cwl
    in:
      genomes_folder: download/downloaded_folder
    out:
      - checkm_csv
      - gtdbtk
      - taxcheck_dir
      - many_genomes
      - one_genome
      - mash_folder

# ---------- second part
  wf-2:
    run: wf-2.cwl
    in:
      many_genomes: wf-1/many_genomes
      mash_folder: wf-1/mash_folder
      one_genome: wf-1/one_genome
      mmseqs_limit_c: mmseqs_limit_c
      mmseqs_limit_i: mmseqs_limit_i
    out:
      - mash_folder
      - many_genomes
      - many_genomes_roary
      - many_genomes_prokka
      - many_genomes_genomes
      - one_genome
      - one_genome_prokka
      - one_genome_genomes
      - mmseqs