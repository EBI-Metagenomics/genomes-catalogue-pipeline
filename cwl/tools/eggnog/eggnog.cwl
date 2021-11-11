#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "eggNOG"

doc: |
  eggNOG is a public resource that provides Orthologous Groups (OGs)
  of proteins at different taxonomic levels, each with integrated and summarized functional annotations.

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.eggnog-mapper:v1"

requirements:
  ResourceRequirement:
    ramMin: 10000
    coresMin: 16

baseCommand: [emapper.py]

inputs:
  fasta_file:
    format: edam:format_1929  # FASTA
    type: File?
    inputBinding:
      separate: true
      prefix: -i
    label: Input FASTA file containing query sequences

  db:
    type: [string?, File?]  # data/eggnog.db
    inputBinding:
      prefix: --database
    label: specify the target database for sequence searches (euk,bact,arch, host:port, local hmmpressed database)

  db_diamond:
    type: [string?, File?]  # data/eggnog_proteins.dmnd
    inputBinding:
      prefix: --dmnd_db
    label: Path to DIAMOND-compatible database

  data_dir:
    type: [string?, Directory?]  # data/
    inputBinding:
      prefix: --data_dir
    label: Directory to use for DATA_PATH

  mode:
    type: string?
    inputBinding:
      prefix: -m
    label: hmmer or diamond

  no_annot:
    type: boolean?
    inputBinding:
      prefix: --no_annot
    label: Skip functional annotation, reporting only hits

  no_file_comments:
    type: boolean?
    inputBinding:
      prefix: --no_file_comments
    label: No header lines nor stats are included in the output files

  cpu:
    type: int?
    inputBinding:
      prefix: --cpu

  annotate_hits_table:
    type: File?
    inputBinding:
      prefix: --annotate_hits_table
    label: Annotatate TSV formatted table of query->hits

  output:
    type: string?
    inputBinding:
      prefix: -o

outputs:

  output_annotations:
    type: File?
    format: edam:format_3475
    outputBinding:
      glob: $(inputs.output)*annotations*

  output_orthologs:
    type: File?
    format: edam:format_3475
    outputBinding:
      glob: $(inputs.output)*orthologs*

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/

$schemas:
 - http://edamontology.org/EDAM_1.20.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:author: "Ekaterina Sakharova"
s:copyrightHolder:
    - name: "EMBL - European Bioinformatics Institute"
    - url: "https://www.ebi.ac.uk/"
s:license: "https://www.apache.org/licenses/LICENSE-2.0"