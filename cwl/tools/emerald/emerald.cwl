#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "emeraldbgc"

doc: |
  SMBGC detection tool.

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/emerald-bgc:v0.2.4.1-genomes-pipeline"

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: ["emeraldbgc"]

inputs:
    ips_output:
        type: File
        inputBinding:
            position: 2
            prefix: --ip-file
        label: Tsv file produced by InterProScan version >5.52-86.0.
    gbk_file:
        type: File
        inputBinding:
            position: 3
        label: Input GenBank file containing sequences and annotations.
    outdirname:
        type: string
        inputBinding:
            position: 4
            prefix: --outdir

outputs:
    emerald_gff:
        type: File
        outputBinding:
            glob: $(inputs.outdirname)/$(inputs.gbk_file.basename).emerald/$(inputs.gbk_file.basename).emerald.full.gff


$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/


