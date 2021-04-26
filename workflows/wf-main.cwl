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
  download_from: string?  # ENA or NCBI
  infile: File?            # file containing a list of GenBank accessions, one accession per line
  directory_name: string?  # directory name to download files to
  unzip: boolean?

  genomes: Directory?

  mmseqs_limit_c: float
  mmseqs_limit_i: float[]


outputs:
  output_csv:
    type: File
    outputSource:
      - download/stats_download_ena
      - wf-1/ncbi_csv
    pickValue: first_non_null

  mash_folder:
    type: Directory?
    outputSource: wf-2/mash_folder

  many_genomes:
    type: Directory[]?
    outputSource: wf-2/many_genomes
  many_genomes_panaroo:
    type: Directory[]?
    outputSource: wf-2/many_genomes_panaroo
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
    outputSource: wf-2/mmseqs_output

  gtdbtk:
    type: Directory
    outputSource: gtdbtk/gtdbtk_folder


steps:
# ----------- << download data >> -----------
  download:
    when: $(inputs.download_from !== undefined)
    run: sub-wf/fetch_data.cwl
    in:
      download_from: download_from
      infile: infile
      directory_name: directory_name
      unzip: unzip
    out:
      - downloaded_folder
      - stats_download_ena

# ---------- first part
  wf-1:
    run: wf-1.cwl
    in:
      type_download: download_from
      ena_csv: download/stats_download_ena
      genomes_folder:
        source:
          - download/downloaded_folder
          - genomes
        pickValue: first_non_null
    out:
      - ncbi_csv
      - many_genomes
      - one_genome
      - mash_folder
      - dereplicated_genomes

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
      - many_genomes_panaroo
      - many_genomes_prokka
      - many_genomes_genomes
      - one_genome
      - one_genome_prokka
      - one_genome_genomes
      - mmseqs_output

# ----------- << GTDB - Tk >> -----------
  gtdbtk:
    run: ../tools/gtdbtk/gtdbtk.cwl
    in:
      drep_folder: wf-1/dereplicated_genomes
      gtdb_outfolder: { default: 'gtdb-tk_output' }
    out: [ gtdbtk_folder ]