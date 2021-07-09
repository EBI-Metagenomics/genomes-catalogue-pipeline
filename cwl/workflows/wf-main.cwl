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
  # download params
  download_from: string?  # ENA or NCBI
  infile: File?            # file containing a list of GenBank accessions, one accession per line
  directory_name: string?  # directory name to download files to
  unzip: boolean?

  # no download
  genomes: Directory?
  csv: File?

  # no gtdbtk
  skip_gtdbtk_step: string

  # common input
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]

  gunc_db_path: File


outputs:
  output_csv:
    type: File?
    outputSource: download/stats_download

  mash_folder:
    type: Directory?
    outputSource: clusters_annotation/mash_folder

  many_genomes:
    type: Directory[]?
    outputSource: clusters_annotation/many_genomes
  many_genomes_panaroo:
    type: Directory[]?
    outputSource: clusters_annotation/many_genomes_panaroo
  many_genomes_prokka:
    type:
      - 'null'
      - type: array
        items:
          type: array
          items: Directory
    outputSource: clusters_annotation/many_genomes_prokka
  many_genomes_genomes:
    type: Directory[]?
    outputSource: clusters_annotation/many_genomes_genomes

  one_genome:
    type: Directory[]?
    outputSource: clusters_annotation/one_genome
  one_genome_prokka:
    type: Directory[]?
    outputSource: clusters_annotation/one_genome_prokka
  one_genome_genomes:
    type: Directory[]?
    outputSource: clusters_annotation/one_genome_genomes

  mmseqs:
    type: Directory
    outputSource: clusters_annotation/mmseqs_output

  gtdbtk:
    type: Directory
    outputSource: gtdbtk/gtdbtk_folder

  flag_no_data:
    type: File?
    outputSource: download/flag_no-data

  weights:
    type: File
    outputSource: drep_subwf/weights_file


steps:
# ----------- << download data >> -----------
  download:
    when: $(Boolean(inputs.download_from))
    run: sub-wf/fetch_data.cwl
    in:
      download_from: download_from
      infile: infile
      directory_name: directory_name
      unzip: unzip
    out:
      - downloaded_folder_ena
      - downloaded_folder_ncbi
      - stats_ena
      - flag_no-data

# ----------- << checkm for NCBI>> -----------
  checkm_subwf:
    run: sub-wf/checkm-subwf.cwl
    when: $(inputs.type == 'NCBI' and !flag)
    in:
      type: download_from
      flag: download/flag_no-data
      genomes_folder: download_from_ncbi/downloaded_files
    out:
      - checkm_csv

# ---------- dRep
  drep_subwf:
    run: sub-wf/drep-subwf.cwl
    in:
      genomes_folder:
        source:
          - download/downloaded_folder
          - genomes
        pickValue: first_non_null
      input_csv:
        source:
          - checkm_subwf/checkm_csv
          - download/stats_ena  # for ENA / NCBI
          - csv  # for no fetch
        pickValue: first_non_null
    out:
      - many_genomes
      - one_genome
      - mash_folder
      - dereplicated_genomes
      - weights_file

# ---------- annotation
  clusters_annotation:
    run: sub-wf/subwf-process_clusters.cwl
    in:
      many_genomes: drep_subwf/many_genomes
      mash_folder: drep_subwf/mash_folder
      one_genome: drep_subwf/one_genome
      mmseqs_limit_c: mmseqs_limit_c
      mmseqs_limit_i: mmseqs_limit_i
      gunc_db_path: gunc_db_path
      csv:
        source:
          - checkm_subwf/checkm_csv
          - download/stats_ena  # for ENA / NCBI
          - csv  # for no fetch
        pickValue: first_non_null
    out:
      - mash_folder
      - many_genomes
      - many_genomes_panaroo
      - many_genomes_prokka
      - many_genomes_genomes
      - one_genome
      - one_genome_prokka
      - one_genome_genomes
      - mmseqs_output

# ----------- << GTDB - Tk >> -----------
  gtdbtk:
    when: $(inputs.skip_flag !== 'skip')
    run: ../tools/gtdbtk/gtdbtk.cwl
    in:
      skip_flag: skip_gtdbtk_step
      drep_folder: drep_subwf/dereplicated_genomes
      gtdb_outfolder: { default: 'gtdb-tk_output' }
    out: [ gtdbtk_folder ]