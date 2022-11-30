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
  drep_folder: Directory
  refdata: Directory
  gtdb_outfolder: string

outputs:

  gtdbtk_outdir:
    type: Directory
    outputSource: gtdbtk/gtdbtk_folder

  taxonomy:
    type: File?
    outputSource:
     - cat_tables/result
     - rename_bac/renamed_file
     - rename_arc/renamed_file
    pickValue: first_non_null


steps:
# ----------- << GTDB - Tk >> -----------

  gtdbtk:
    run: ../../tools/gtdbtk/gtdbtk.cwl
    in:
      drep_folder: drep_folder
      gtdb_outfolder: gtdb_outfolder
      refdata: refdata
    out:
      - gtdbtk_folder
      - gtdbtk_bac
      - gtdbtk_arc

  cat_tables:
    when: $(Boolean(inputs.file1) && Boolean(inputs.file2))
    run: ../../utils/concatenate.cwl
    in:
      file1: gtdbtk/gtdbtk_bac
      file2: gtdbtk/gtdbtk_arc
      files:
        - gtdbtk/gtdbtk_bac
        - gtdbtk/gtdbtk_arc
      outputFileName: {default: "gtdbtk.summary.tsv" }
    out: [result]

  rename_bac:
    when: $(Boolean(inputs.file1) && !Boolean(inputs.file2))
    run: ../../utils/move.cwl
    in:
      file1: gtdbtk/gtdbtk_bac
      file2: gtdbtk/gtdbtk_arc
      initial_file: gtdbtk/gtdbtk_bac
      out_file_name: {default: "gtdbtk.summary.tsv" }
    out: [renamed_file]

  rename_arc:
    when: $(!Boolean(inputs.file1) && Boolean(inputs.file2))
    run: ../../utils/move.cwl
    in:
      file1: gtdbtk/gtdbtk_bac
      file2: gtdbtk/gtdbtk_arc
      initial_file: gtdbtk/gtdbtk_arc
      out_file_name: {default: "gtdbtk.summary.tsv" }
    out: [renamed_file]

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"