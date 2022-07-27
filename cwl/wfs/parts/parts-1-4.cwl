#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  genomes_ena: Directory?
  ena_csv: File?
  genomes_ncbi: Directory?

  max_accession_mgyg: int
  min_accession_mgyg: int
  ftp_name_catalogue: string
  ftp_version_catalogue: string

  # skip dRep step if MAGs were already dereplicated and provide Sdb.csv, Mdb.csv and Cdb.csv
  skip_drep_step: boolean   # set True for skipping
  sdb_dereplicated: File?
  cdb_dereplicated: File?
  mdb_dereplicated: File?

  # no gtdbtk
  skip_gtdbtk_step: boolean   # set True for skipping

  # common input
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]
  mmseq_limit_annotation: float

  gunc_db_path: File

  gtdbtk_data: Directory?

  interproscan_databases: [string, Directory]
  chunk_size_ips: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

  cm_models: Directory
  kegg_db: File
  geo_metadata: File
  biom: string

  claninfo_ncrna: File
  models_ncrna:
    type: File
    secondaryFiles:
      - .i1f
      - .i1i
      - .i1m
      - .i1p

outputs:

# ------- intermediate files -------
  intermediate_files:
    type: Directory
    outputSource: folder_with_intermediate_files/out

  mgyg_genomes:
    type: Directory
    outputSource: folder_with_genomes/out

# ------- clusters_annotation -------

#  annotated_clusters:
#    type: Directory[]
#    outputSource: post_processing/annotations_cluster_dir

  mmseqs:
    type: Directory
    outputSource: create_protein_catalogue_folder_ftp/protein_catalogue_final_folder

  panaroo:
    type: Directory
    outputSource: process_clusters/panaroo_folder

# ---------- rRNA -------------
  rrna_out:
    type: Directory
    outputSource: annotation/rrna_out

  rrna_fasta:
    type: Directory
    outputSource: annotation/rrna_fasta

# -- for next steps
  ips_eggnog:
    type: File[]
    outputSource: annotation/ips_eggnog_annotations
  clusters_pangenome:
    type: Directory[]
    outputSource: process_clusters/clusters_pangenome
  clusters_singletons:
    type: Directory[]
    outputSource: process_clusters/clusters_singletons
  gffs:
    type: File[]
    outputSource: process_clusters/pangenome_other_gffs

# ---------- GFF ----------
#  gff_ftp:
#    type: Directory
#    outputSource: create_gff_folder_ftp/gffs_folder

# ------------ GTDB-Tk --------------
#  gtdbtk:
#    type: Directory?
#    outputSource: gtdbtk_metadata/gtdbtk_outdir

#  metadata:
#    type: File?
#    outputSource: gtdbtk_metadata/metadata

#  phylo_json:
#    type: File?
#    outputSource: gtdbtk_metadata/phylo_tree

steps:

# ----------- << 1. checkM + assign MGYG >> -----------
# - checkM for NCBI
# - unite folders for ENA and NCBI
# - unite stats files for ENA and NCBI
# - assign MGYGs

  preparation:
    run: ../../sub-wfs/wf-1-preparation.cwl
    in:
      genomes_ena: genomes_ena
      ena_csv: ena_csv
      genomes_ncbi: genomes_ncbi
      max_accession_mgyg: max_accession_mgyg
      min_accession_mgyg: min_accession_mgyg
    out:
      - checkm_stderr
      - checkm_stdout
      - unite_folders_csv
      - assign_mgygs_renamed_genomes
      - assign_mgygs_renamed_csv
      - assign_mgygs_naming_table

# ---------- 2. dRep + split -----------
# - extra_weights generation
# - dRep
# - split dRep, create mash-folder
# - classify to pangenomes and singletons

  drep_subwf:
    run: ../../sub-wfs/wf-2-drep.cwl
    in:
      genomes_folder: preparation/assign_mgygs_renamed_genomes
      input_csv: preparation/assign_mgygs_renamed_csv
      # ---- for dereplicated set ---- [needs testing]
      skip_flag: skip_drep_step
      sdb_dereplicated: sdb_dereplicated
      cdb_dereplicated: cdb_dereplicated
      mdb_dereplicated: mdb_dereplicated
    out:
      - many_genomes
      - one_genome
      - mash_files
      - best_cluster_reps
      - weights_file
      - split_text
      - cdb
      - mdb

# ----------- << 3. process clusters >> ------
# - mash2nwk
# - process pangenomes
# - process singletons
# - mmseqs

  process_clusters:
    run: ../../sub-wfs/wf-3-process_clusters.cwl
    in:
      many_genomes: drep_subwf/many_genomes
      mash_folder: drep_subwf/mash_files
      one_genome: drep_subwf/one_genome
      csv: preparation/assign_mgygs_renamed_csv
      gunc_db_path: gunc_db_path
      mmseqs_limit_c: mmseqs_limit_c
      mmseqs_limit_i: mmseqs_limit_i
      mmseq_limit_annotation: mmseq_limit_annotation
    out:
      - clusters_pangenome
      - clusters_singletons
      - other_pangenome_fna
      - all_singletons_fna
      - reps_pangenomes_fna
      - pangenome_other_gffs
      - singletons_gunc_completed
      - singletons_gunc_failed
      - panaroo_folder
      - mmseq_dirs          # Dir[]?
      - mmseq_ann_dir       # Dir?
      - mmseq_cluster_rep_faa
      - mmseq_cluster_tsv
      - file_all_reps_filt_fna

# ----------- << 4. annotation >> ------
# - IPS + eggNOG
# - per_genome_annotations
# - rRNA prediction

  annotation:
    run: ../../sub-wfs/wf-4-annotation.cwl
    in:
      mmseqs_faa: process_clusters/mmseq_cluster_rep_faa
      mmseqs_tsv: process_clusters/mmseq_cluster_tsv
      all_reps_filtered: process_clusters/file_all_reps_filt_fna
      all_fnas:
        source:
          - process_clusters/reps_pangenomes_fna
          - process_clusters/other_pangenome_fna
          - process_clusters/all_singletons_fna
        linkMerge: merge_flattened
      interproscan_databases: interproscan_databases
      chunk_size_ips: chunk_size_ips
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog
      cm_models: cm_models
    out:
      - ips_eggnog_annotations  # File[]
      - ips_tsv
      - eggnog_tsv
      - rrna_out                # Dir
      - rrna_fasta              # Dir


# ---------- << 8. create protein_catalogue folder for FTP >> ----------
  create_protein_catalogue_folder_ftp:
    run: ../../sub-wfs/wf-8-create-protein_catalogue.cwl
    in:
      mmseq_dirs: process_clusters/mmseq_dirs
      mmseq_ann_folder: process_clusters/mmseq_ann_dir
      ips: annotation/ips_tsv
      eggnog: annotation/eggnog_tsv
    out: [ protein_catalogue_final_folder ]

# ---------- << 9. create intermediate_files for FTP>> ----------
  folder_with_intermediate_files:
    run: ../../utils/return_directory.cwl
    in:
      list:
        source:
          - preparation/checkm_stderr                                   # checkm.err
          - preparation/checkm_stdout                                   # checkm.out
          - preparation/unite_folders_csv                               # initail csv
          - preparation/assign_mgygs_renamed_csv                        # MGYG csv
          - preparation/assign_mgygs_naming_table                       # mapping initial names to MGYGs
          - drep_subwf/weights_file                                     # weights drep
          - drep_subwf/best_cluster_reps                                # Sdb.csv
          - drep_subwf/cdb                                              # Cdb.csv
          - drep_subwf/mdb                                              # Mdb.csv
          - drep_subwf/split_text                                       # split by clusters file
          - process_clusters/singletons_gunc_completed                  # gunc passed genomes list
          - process_clusters/singletons_gunc_failed                     # gunc failed genomes list
        pickValue: all_non_null
      dir_name: { default: 'intermediate_files'}
    out: [ out ]

# ---------- << 10. create mgyg_genomes folder without GUNC-failed genomes>> ----------
  folder_with_genomes:
    run: ../../utils/return_directory.cwl
    in:
      list:
        source:
          - process_clusters/reps_pangenomes_fna
          - process_clusters/other_pangenome_fna
          - process_clusters/all_singletons_fna
        linkMerge: merge_flattened
        pickValue: all_non_null
      dir_name: { default: 'mgyg_genomes'}
    out: [ out ]