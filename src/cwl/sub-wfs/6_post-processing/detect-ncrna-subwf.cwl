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
  claninfo: File
  models:
    type: File
    secondaryFiles:
      - .i1f
      - .i1i
      - .i1m
      - .i1p
  fasta: File

outputs:
  cmscan_deoverlap:
    type: File
    outputSource: deoverlap/deoverlapped_table

steps:

  cmscan:
    run: ../../tools/post-processing/cmscan/cmscan.cwl
    in:
      cpu: { default: 4 }
      tblout:
        source: fasta
        valueFrom: "$(self.nameroot).cmscan.tbl"
      claninfo: claninfo
      models: models
      fasta: fasta
    out: [ cmscan_result ]

  deoverlap:
    run: ../../utils/deoverlap.cwl
    in:
      cmscan: cmscan/cmscan_result
      outputname:
        source: fasta
        valueFrom: "$(self.nameroot).cmscan-deoverlap.tbl"
    out: [ deoverlapped_table ]

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"