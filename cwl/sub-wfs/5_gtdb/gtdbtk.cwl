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
    outputSource: cat_tables/result


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
    when: $(Boolean(inputs.file1) || Boolean(inputs.file2))
    run: ../../utils/concatenate.cwl
    in:
      file1: gtdbtk/gtdbtk_bac
      file2: gtdbtk/gtdbtk_arc
      files:
        source:
          - gtdbtk/gtdbtk_bac
          - gtdbtk/gtdbtk_arc
        pickValue: all_non_null
      outputFileName: {default: "gtdbtk.summary.tsv" }
    out: [result]

  # tar:
  #  run: ../../utils/tar.cwl
  #  in:
  #    folder: gtdbtk/gtdbtk_folder
  #  out: [ folder_tar ]


