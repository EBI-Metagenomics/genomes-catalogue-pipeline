cwlVersion: v1.2
class: Workflow

label: "Setting up large annotation job for eggnog"
doc: |
  Chunk fasta file -> scatter to find seed orthologs -> unite them -> find annotations
  instructions:
  https://github.com/eggnogdb/eggnog-mapper/wiki/eggNOG-mapper-v2.1.2-to-v2.1.4#setting-up-large-annotation-jobs

requirements:
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  faa_file: File
  chunk_size: int
  db_diamond: [string?, File?]
  db: [string?, File?]
  data_dir: [string?, Directory?]
  cpu: int

outputs:
  annotations:
    type: File
    outputSource: eggnog_annotation/output_annotations
  seed_orthologs:
    type: File
    outputSource: unite_seed_orthologs/result

steps:

  # << Chunk faa file >>
  split_seqs:
    in:
      seqs: faa_file
      chunk_size: chunk_size
    out: [ chunks ]
    run: ../../tools/protein_chunker/protein_chunker.cwl

  eggnog_homology_searches:
    scatter: fasta_file
    run: ../../tools/eggnog/eggnog.cwl
    in:
      fasta_file: split_seqs/chunks
      db_diamond: db_diamond
      db: db
      data_dir: data_dir
      no_annot: {default: true}
      no_file_comments: {default: true}
      cpu: cpu
      output:
        source: faa_file
        valueFrom: $(self.nameroot)
      mode: { default: diamond }
    out: [ output_orthologs ]

  unite_seed_orthologs:
    run: ../../utils/concatenate.cwl
    in:
      files: eggnog_homology_searches/output_orthologs
      outputFileName:
        source: faa_file
        valueFrom: $(self.nameroot).emapper.seed_orthologs
    out: [result]

  eggnog_annotation:
    run: ../../tools/eggnog/eggnog.cwl
    in:
      annotate_hits_table: unite_seed_orthologs/result
      data_dir: data_dir
      no_file_comments: {default: true}
      cpu: cpu
      output:
        source: faa_file
        valueFrom: $(self.nameroot)
    out: [ output_annotations ]


$namespaces:
  edam: 'http://edamontology.org/'
  s: 'http://schema.org/'

$schemas:
  - 'http://edamontology.org/EDAM_1.16.owl'
  - 'https://schema.org/version/latest/schemaorg-current-http.rdf'
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute, 2018"
s:author: "Ekaterina Sakharova"