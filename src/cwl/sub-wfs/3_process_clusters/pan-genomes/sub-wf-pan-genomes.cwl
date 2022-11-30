#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Subwf processes one cluster with more than one genome inside
  Steps:
    1) prokka
    2) panaroo
    3) detect core genes
    4) filter mash file
    5) return final folder cluster_NUM

  Output:
    genome.panaroo.tar.gz
    cluster: File[]
         --- core_genes                 [ pangenome ]
         --- mash-file.nwk              [ pangenome ]
         --- pan_genome_reference       [ pangenome ]
         --- gene_presence_absence      [ pangenome ]
         --- rep.faa                    [ genome ]
         --- rep.gff                    [ genome ]
         --- rep.fna                    [ genome ]
    FNAs (all) File[]
    FAAs (all) File[]
    gffs / main_rep.gff

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  cluster: Directory
  mash_files: File[]

outputs:
  panaroo_outdir:
    type: Directory
    outputSource: panaroo/panaroo_dir

  pangenome_other_fnas:
    type: File[]
    outputSource: get_pangenome_fnas/left_files

  all_pangenome_faa:
    type: File[]
    outputSource: prokka/faa

  pangenome_cluster:
    type: Directory
    outputSource: cluster_folder/out

  pangenome_other_gffs:
    type: File[]
    outputSource: get_pangenome_gffs/left_files

  main_rep_fna:
    type: File
    outputSource: choose_main_rep_fna/file_pattern


steps:
  preparation:
    run: ../../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [files]

  prokka:
    run: ../prokka-subwf.cwl
    scatter: prokka_input
    in:
      prokka_input: preparation/files
      outdirname: {default: prokka_output }
    out:
      - gff
      - faa
      - fna
# --------------------------------------- pan-genome specific -----------------------------------------

  panaroo:
    run: panaroo-subwf.cwl
    in:
      prokka_gffs: prokka/gff
      panaroo_folder_name:
        source: cluster
        valueFrom: "$(self.basename)_panaroo"
    out:
      - gene_presence_absence
      - panaroo_fna
      - panaroo_dir

  rename_panaroo_fna:
    # For some reason move.cwl (mv) doesn't work to rename the file 
    run: ../../../utils/cp.cwl
    in:
      source_file: panaroo/panaroo_fna
      destination_file_name:
        source: cluster
        valueFrom: "$(self.basename).pan-genome.fna"
    out: [ copied_file ]

  get_core_genes:
    run: ../../../tools/genomes-catalog-update/get_core_genes/get_core_genes.cwl
    in:
      input: panaroo/gene_presence_absence
      output_filename:
        source: cluster
        valueFrom: "$(self.basename).core_genes.txt"
    out:
      - core_genes

  get_mash_file:
    doc: |
       Filter mash files by cluster name
       For example: cluster_1_1 should have 1_1.tree.mash inside
                    filtering pattern: "1_1"
    run: ../../../utils/get_file_pattern.cwl
    in:
      list_files: mash_files
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]


  get_pangenome_gffs:
    run: ../../../utils/exclude_file_pattern.cwl
    in:
      list_files: prokka/gff
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ left_files ]

  get_pangenome_fnas:
    run: ../../../utils/exclude_file_pattern.cwl
    in:
      list_files: prokka/fna
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ left_files ]

# --------------------------------------- genome specific -----------------------------------------

  choose_main_rep_gff:
    run: ../../../utils/get_file_pattern.cwl
    in:
      list_files: prokka/gff
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]

  choose_main_rep_faa:
    run: ../../../utils/get_file_pattern.cwl
    in:
      list_files: prokka/faa
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]

  choose_main_rep_fna:
    run: ../../../utils/get_file_pattern.cwl
    in:
      list_files: prokka/fna
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]

# --------------------------------------- final folder -----------------------------------------

  cluster_folder:
    run: ../../../utils/return_directory.cwl
    in:
      list:
        - rename_panaroo_fna/copied_file # renamed: panaroo/pan_genome_reference.fa 
        - panaroo/gene_presence_absence
        - get_core_genes/core_genes
        - get_mash_file/file_pattern
        - choose_main_rep_gff/file_pattern
        - choose_main_rep_faa/file_pattern
        - choose_main_rep_fna/file_pattern
      dir_name:
        source: cluster
        valueFrom: $(self.basename)
    out: [ out ]

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"