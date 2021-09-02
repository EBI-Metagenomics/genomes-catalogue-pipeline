#!/usr/bin/env cwl-runner
class: Workflow
cwlVersion: v1.2

requirements:
  ResourceRequirement:
      ramMin: 1000
      coresMin: 1
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}

inputs:

  faa: File
  chunk_size: int
  InterProScan_databases: [string, Directory]

outputs:
  ips_result:
    type: File
    outputSource: combine_ips/result

steps:
  # << Chunk faa file >>
  split_seqs:
    in:
      seqs: faa
      chunk_size: chunk_size
    out: [ chunks ]
    run: ../../tools/protein_chunker/protein_chunker.cwl

  # << InterProScan >>
  interproscan:
    scatter: inputFile
    in:
      inputFile: split_seqs/chunks
      databases: InterProScan_databases
    out: [ annotations ]
    run: ../../tools/IPS/InterProScan.cwl
    label: "InterProScan: protein sequence classifier"

  combine_ips:
    in:
      files: interproscan/annotations
      outputFileName:
        source: faa
        valueFrom: $(self.nameroot).IPS.tsv
    out: [result]
    run: ../../utils/concatenate.cwl


$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - name: "EMBL - European Bioinformatics Institute"
  - url: "https://www.ebi.ac.uk/"
