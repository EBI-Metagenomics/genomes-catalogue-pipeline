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

  skip_drep_step: boolean   # set True for skipping

outputs:

# ------- unite_folders -------
  output_csv:
    type: File
    outputSource: unite_folders/csv

# ------- assign_mgygs -------
  renamed_csv:
    type: File
    outputSource: assign_mgygs/renamed_csv
  naming_table:
    type: File
    outputSource: assign_mgygs/naming_table
  renamed_genomes:
    type: Directory
    outputSource: assign_mgygs/renamed_genomes

# ------- drep -------
  weights:
    type: File?
    outputSource: generate_weights/file_with_weights
  best_cluster_reps_drep:                           # remove
    type: File?
    outputSource: drep/Sdb_csv
  split_test_helper:                                # remove
    type: File?
    outputSource: split_drep/split_text
  mash_drep:                                        # remove
    type: File[]?
    outputSource: split_drep/split_out_mash
  one_clusters:                                     # remove
    type: Directory[]?
    outputSource: filter_nulls/out_dirs
  many_clusters:                                    # remove
    type: Directory[]?
    outputSource: classify_clusters/many_genomes


steps:

# ----------- << checkm for NCBI >> -----------
  checkm_subwf:
    run: ../../sub-wf/checkm-subwf.cwl
    when: $(Boolean(inputs.genomes_folder))
    in:
      genomes_folder: genomes_ncbi
    out:
      - checkm_csv

# ----------- << unite NCBI and ENA >> -----------
  unite_folders:
    run: ../../../tools/unite_ena_ncbi/unite.cwl
    when: $(Boolean(inputs.ncbi_folder) && Boolean(inputs.ena_folder))
    in:
      ena_folder: genomes_ena
      ncbi_folder: genomes_ncbi
      ena_csv: ena_csv
      ncbi_csv: checkm_subwf/checkm_csv
      outputname: { default: "genomes"}
    out:
      - genomes
      - csv

# ----------- << assign MGYGs >> -----------
  assign_mgygs:
    run: ../../../tools/rename_fasta/rename_fasta.cwl
    in:
      genomes:
        source:
          - unite_folders/genomes
          - genomes_ena
          - genomes_ncbi
        pickValue: first_non_null
      prefix: { default: "MGYG"}
      start_number: min_accession_mgyg
      max_number: max_accession_mgyg
      output_filename: { default: "names.tsv"}
      output_dirname: { default: "mgyg_genomes" }
      csv:
        source:
          - unite_folders/csv
          - ena_csv
          - checkm_subwf/checkm_csv
        pickValue: first_non_null
    out:
      - naming_table
      - renamed_genomes
      - renamed_csv

# ---------- dRep + split -----------
  generate_weights:
    when: $(!Boolean(inputs.flag))
    run: ../../../tools/generate_weight_table/generate_extra_weight_table.cwl
    in:
      flag: skip_drep_step
      input_directory: assign_mgygs/renamed_genomes
      output: { default: "extra_weight_table.txt" }
    out: [ file_with_weights ]

  drep:
    when: $(!Boolean(inputs.flag))
    run: ../../../tools/drep/drep.cwl
    in:
      flag: skip_drep_step
      genomes: assign_mgygs/renamed_genomes
      drep_outfolder: { default: 'drep_outfolder' }
      csv: assign_mgygs/renamed_csv
      extra_weights: generate_weights/file_with_weights
    out:
      - Cdb_csv
      - Mdb_csv
      - Sdb_csv

  split_drep:
    when: $(!Boolean(inputs.flag))
    run: ../../../tools/drep/split_drep.cwl
    in:
      flag: skip_drep_step
      Cdb_csv: drep/Cdb_csv
      Mdb_csv: drep/Mdb_csv
      split_outfolder: { default: 'split_outfolder' }
    out:
      - split_out_mash
      - split_text

  classify_clusters:
    when: $(!Boolean(inputs.flag))
    run: ../../../tools/drep/classify_folders.cwl
    in:
      flag: skip_drep_step
      genomes: assign_mgygs/renamed_genomes
      text_file: split_drep/split_text
    out:
      - many_genomes
      - one_genome

  classify_dereplicated:
    when: $(Boolean(inputs.flag))
    run: ../../../tools/drep/classify_dereplicated.cwl
    in:
      flag: skip_drep_step
      clusters: assign_mgygs/renamed_genomes
    out:
      - one_genome

  filter_nulls:
    run: ../../../utils/filter_nulls.cwl
    in:
      list_dirs:
        source:
          - classify_clusters/one_genome
          - classify_dereplicated/one_genome
        linkMerge: merge_flattened
        pickValue: all_non_null
    out: [ out_dirs ]
