#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Workflow to process clusters returned from dRep step.
  Steps:
    - convert all mash.tsv to mash.nwk
    - process pan-genomes
    - process singletons
    - mmseqs
  output:
    - clusters_pangenomes:
       Dir[]:
         - panaroo.fna
         - panaroo.gene_presence_absence
         - core_genes.txt
         - genome.mash.nwk
         - main_genome.fna
         - main_genome.faa
         - main_genome.gff
    - clusters_singletons:
       Dir[]:
         - genome.fna
         - genome.faa
         - genome.gff
    - list_of_aLL_main_reps
    - FNA-s:
      - all_singletons_fna (all singletons initial fnas excluded genomes filtered by GUNC)
      - reps_pangenomes_fna (cluster reps for pan-genomes)
      - other_pangenome_fna (non cluster reps for pan-genomes)
    - GFF-s:
      - pangenome_other_gffs (gffs for non cluster pan-genome clusters)
    - GUNC
      - singletons_gunc_completed (list of singletons passed GUNC)
      - singletons_gunc_failed (list of singletons filtered by GUNC)
    - panaroo_output (folder with genome_panaroo.tar.gz-s)
    - mmseqs
      - mmseq_dirs (3 mmseq.tar.gz)
      - mmseq_ann_dir (mmseqs directory of 0.9)
      - mmseq_cluster_rep_faa (mmseq.0.9.reps.faa)
      - mmseq_cluster_tsv (mmseq.0.9.tsv)


requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  many_genomes: Directory[]?
  mash_folder: File[]?

  one_genome: Directory[]?
  csv: File
  gunc_db_path: File

  mmseqs_limit_i: float[]
  mmseqs_limit_c: float
  mmseq_limit_annotation: float

outputs:

  clusters_pangenome:
    type: Directory[]
    outputSource: process_many_genomes/pangenome_clusters

  clusters_singletons:
    type: Directory[]
    outputSource: process_one_genome/singleton_clusters

  file_all_reps_filt_fna:
    type: File
    outputSource: get_reps/list

# ===== fna =======
  other_pangenome_fna:
    type: File[]
    outputSource: process_many_genomes/pangenome_other_fnas

  reps_pangenomes_fna:
    type: File[]
    outputSource: process_many_genomes/reps_fna

  all_singletons_fna:
    type: File[]
    outputSource: process_one_genome/all_filt_sigletons_fna

# ===== gff =======
  pangenome_other_gffs:
    type: File[]
    outputSource: process_many_genomes/other_pangenome_gffs

# ===== gunc =======
  singletons_gunc_completed:
    type: File
    outputSource: process_one_genome/gunc_completed

  singletons_gunc_failed:
    type: File
    outputSource: process_one_genome/gunc_failed

# ===== panaroo ftp =======
  panaroo_folder:
    type: Directory
    outputSource: process_many_genomes/panaroo_output

# ===== mmseqs =======
  mmseq_dirs:
    type: File[]?
    outputSource: mmseqs/mmseqs_dirs
  mmseq_ann_dir:
    type: Directory?
    outputSource: mmseqs/mmseqs_annotation_dir
  mmseq_cluster_rep_faa:
    type: File
    outputSource: mmseqs/cluster_reps
  mmseq_cluster_tsv:
    type: File
    outputSource: mmseqs/cluster_tsv

steps:

# ----------- << mash trees >> -----------
  process_mash:
    scatter: input_mash
    run: ../tools/mash2nwk/mash2nwk.cwl
    in:
      input_mash: mash_folder
    out: [mash_tree]  # File[]

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    when: $(Boolean(inputs.input_clusters))
    run: 3_process_clusters/pan-genomes/wrapper-pan-genomes.cwl
    in:
      input_clusters: many_genomes
      mash_folder: process_mash/mash_tree
    out:
      - panaroo_output
      - all_pangenome_faa
      - other_pangenome_gffs
      - pangenome_clusters
      - reps_fna
      - pangenome_other_fnas

# ----------- << one genome cluster processing >> -----------
  process_one_genome:
    when: $(Boolean(inputs.input_cluster))
    run: 3_process_clusters/singletons/wrapper-singletons.cwl
    in:
      input_cluster: one_genome
      csv: csv
      gunc_db_path: gunc_db_path
    out:
      - singleton_clusters      # File[][]?
      - all_filt_sigletons_fna   # faa[]?
      - all_filt_sigletons_faa  # fna[]?
      - gunc_completed
      - gunc_failed

# ----------- << mmseqs >> -----------
  mmseqs:
    run: 3_process_clusters/mmseq-subwf.cwl
    in:
      prokka_many: process_many_genomes/all_pangenome_faa
      prokka_one: process_one_genome/all_filt_sigletons_faa
      mmseqs_limit_i: mmseqs_limit_i
      mmseqs_limit_c: mmseqs_limit_c
      mmseq_limit_annotation: mmseq_limit_annotation
    out:
      - mmseqs_dirs
      - mmseqs_annotation_dir
      - cluster_reps
      - cluster_tsv

# ----------- << get list of cluster reps filtered>> -----------
  get_reps:
    run: ../utils/list_of_basenames.cwl
    in:
      files:
        source:
          - process_many_genomes/reps_fna
          - process_one_genome/all_filt_sigletons_fna
        linkMerge: merge_flattened
      name: { default: "list_reps_filtered.txt"}
    out: [ list ]