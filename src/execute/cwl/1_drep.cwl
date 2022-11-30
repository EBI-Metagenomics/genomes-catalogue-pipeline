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

  # skip dRep step if MAGs were already dereplicated and provide Sdb.csv, Mdb.csv and Cdb.csv
  skip_drep_step: boolean   # set True for skipping
  sdb_dereplicated: File?
  cdb_dereplicated: File?
  mdb_dereplicated: File?

outputs:

# ------- intermediate files -------
  intermediate_files:
    type: Directory
    outputSource: folder_with_intermediate_files/out

  pangenomes:
    type: Directory
    outputSource: wrap_pan_genomes/pool_directory

  singletons:
    type: Directory
    outputSource: wrap_singletons/pool_directory

  mash:
    type: Directory
    outputSource: wrap_mash/out


steps:

# ----------- << 1. checkM + assign MGYG >> -----------
# - checkM for NCBI
# - unite folders for ENA and NCBI
# - unite stats files for ENA and NCBI
# - assign MGYGs

  preparation:
    run: ../../cwl/sub-wfs/wf-1-preparation.cwl
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
    run: ../../cwl/sub-wfs/wf-2-drep.cwl
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

  wrap_pan_genomes:
    run: ../../cwl/utils/return_dir_of_dir.cwl
    in:
      directory_array: drep_subwf/many_genomes
      newname: {default: "pan-genomes"}
    out: [ pool_directory ]

  wrap_singletons:
    run: ../../cwl/utils/return_dir_of_dir.cwl
    in:
      directory_array: drep_subwf/one_genome
      newname: {default: "singletons"}
    out: [ pool_directory ]

  wrap_mash:
    run: ../../cwl/utils/return_directory.cwl
    in:
      list: drep_subwf/mash_files
      dir_name: {default: "mash"}
    out: [ out ]

# ---------- << create intermediate_files for FTP>> ----------
  folder_with_intermediate_files:
    run: ../../cwl/utils/return_directory.cwl
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
        pickValue: all_non_null
      dir_name: { default: 'intermediate_files'}
    out: [ out ]

