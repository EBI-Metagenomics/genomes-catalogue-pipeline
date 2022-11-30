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
  input_clusters: Directory[]
  mash_folder: File[]

outputs:

  panaroo_output:
    type: Directory
    outputSource: panaroo_final_folder/pool_directory

  other_pangenome_gffs:
    type: File[]
    outputSource: flatten_other_gffs/array1d
  all_pangenome_faa:
    type: File[]
    outputSource: flatten_faas/array1d

  reps_fna:
    type: File[]
    outputSource: process_many_genomes/main_rep_fna
  pangenome_other_fnas:
    type: File[]
    outputSource: flatten_other_fnas/array1d

  pangenome_clusters:
    type: Directory[]
    outputSource: process_many_genomes/pangenome_cluster

steps:

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    run: sub-wf-pan-genomes.cwl
    scatter: cluster
    in:
      cluster: input_clusters
      mash_files: mash_folder
    out:
      - panaroo_outdir
      - pangenome_other_fnas
      - all_pangenome_faa
      - pangenome_cluster
      - pangenome_other_gffs
      - main_rep_fna

  flatten_other_gffs:
    run: ../../../utils/flatten_array.cwl
    in:
      arrayTwoDim: process_many_genomes/pangenome_other_gffs
    out: [ array1d ]

  flatten_other_fnas:
    run: ../../../utils/flatten_array.cwl
    in:
      arrayTwoDim: process_many_genomes/pangenome_other_fnas
    out: [ array1d ]

  flatten_faas:
    run: ../../../utils/flatten_array.cwl
    in:
      arrayTwoDim: process_many_genomes/all_pangenome_faa
    out: [ array1d ]

  panaroo_final_folder:
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      directory_array: process_many_genomes/panaroo_outdir
      newname: { default: panaroo_output }
    out: [ pool_directory ]

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"